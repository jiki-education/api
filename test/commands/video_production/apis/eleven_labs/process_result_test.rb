require "test_helper"

class VideoProduction::APIs::ElevenLabs::ProcessResultTest < ActiveSupport::TestCase
  test "downloads audio from ElevenLabs, uploads to S3, and updates node" do
    pipeline = create(:video_production_pipeline)
    script_node = create(:video_production_node,
      pipeline:,
      type: 'asset',
      asset: { 'content' => 'Hello world this is a test script' })
    node = create(:video_production_node,
      pipeline:,
      status: 'in_progress',
      metadata: { process_uuid: 'test-uuid' },
      inputs: { 'script' => [script_node.uuid] })

    audio_url = 'https://api.elevenlabs.io/v1/audio/123.mp3'
    audio_data = 'fake-audio-binary-data'

    # Mock download from ElevenLabs
    stub_request(:get, audio_url).
      with(headers: { 'xi-api-key' => Jiki.secrets.elevenlabs_api_key }).
      to_return(status: 200, body: audio_data)

    # Mock S3 upload via Utils::S3::Upload
    # The s3_key will have a UUID, so we match with anything and capture the key
    captured_s3_key = nil
    Utils::S3::Upload.expects(:call).with do |key, body, content_type, bucket|
      captured_s3_key = key
      key.start_with?("pipelines/#{pipeline.uuid}/nodes/#{node.uuid}/") &&
        key.end_with?('.mp3') &&
        body == audio_data &&
        content_type == 'audio/mpeg' &&
        bucket == :video_production
    end.returns do # rubocop:disable Style/MultilineBlockChain
      captured_s3_key
    end

    VideoProduction::APIs::ElevenLabs::ProcessResult.(node.uuid, 'test-uuid', audio_url)

    node.reload
    assert_equal 'completed', node.status
    assert_match(%r{\Apipelines/#{Regexp.escape(pipeline.uuid)}/nodes/#{Regexp.escape(node.uuid)}/[a-f0-9-]+\.mp3\z}, node.output['s3Key'])
    assert_equal 'audio', node.output['type']
    assert_equal audio_data.bytesize, node.output['size']
    refute_nil node.metadata['completed_at']
  end

  test "raises error when download fails" do
    pipeline = create(:video_production_pipeline)
    node = create(:video_production_node,
      pipeline:,
      status: 'in_progress',
      metadata: { process_uuid: 'test-uuid' },
      inputs: { 'script' => [] })

    audio_url = 'https://api.elevenlabs.io/v1/audio/123.mp3'

    stub_request(:get, audio_url).to_return(status: 404, body: 'Not Found')

    error = assert_raises(RuntimeError) do
      VideoProduction::APIs::ElevenLabs::ProcessResult.(node.uuid, 'test-uuid', audio_url)
    end

    assert_match(/Failed to download audio from ElevenLabs/, error.message)
  end

  test "uses database lock when updating node" do
    pipeline = create(:video_production_pipeline)
    node = create(:video_production_node,
      pipeline:,
      status: 'in_progress',
      metadata: { process_uuid: 'test-uuid' },
      inputs: { 'script' => [] })

    audio_url = 'https://api.elevenlabs.io/v1/audio/123.mp3'

    stub_request(:get, audio_url).to_return(status: 200, body: 'audio')
    Utils::S3::Upload.stubs(:call).returns("pipelines/#{pipeline.uuid}/nodes/#{node.uuid}/#{SecureRandom.uuid}.mp3")

    # Mock with_lock to verify it's called
    VideoProduction::Node.any_instance.expects(:with_lock).yields

    VideoProduction::APIs::ElevenLabs::ProcessResult.(node.uuid, 'test-uuid', audio_url)
  end
end
