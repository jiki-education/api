require "test_helper"

class VideoProduction::APIs::Heygen::ProcessResultTest < ActiveSupport::TestCase
  test "downloads video from HeyGen, uploads to S3, and updates node" do
    pipeline = create(:video_production_pipeline)
    audio_node = create(:video_production_node,
      pipeline:,
      type: 'generate-voiceover',
      output: { 's3Key' => 'audio.mp3' })
    node = create(:video_production_node,
      pipeline:,
      status: 'in_progress',
      metadata: { process_uuid: 'test-uuid' },
      inputs: { 'audio' => [audio_node.uuid] })

    video_url = 'https://heygen.com/video/123.mp4'
    video_data = 'fake-video-binary-data'

    # Mock download from HeyGen (no authentication header needed for direct video URL)
    stub_request(:get, video_url).
      to_return(status: 200, body: video_data)

    # Mock S3 upload via Utils::S3::Upload
    captured_s3_key = nil
    Utils::S3::Upload.expects(:call).with do |key, body, content_type, bucket|
      captured_s3_key = key
      key.start_with?("pipelines/#{pipeline.uuid}/nodes/#{node.uuid}/") &&
        key.end_with?('.mp4') &&
        body == video_data &&
        content_type == 'video/mp4' &&
        bucket == :video_production
    end.returns do # rubocop:disable Style/MultilineBlockChain
      captured_s3_key
    end

    VideoProduction::APIs::Heygen::ProcessResult.(node.uuid, 'test-uuid', video_url)

    node.reload
    assert_equal 'completed', node.status
    assert_match(%r{\Apipelines/#{Regexp.escape(pipeline.uuid)}/nodes/#{Regexp.escape(node.uuid)}/[a-f0-9-]+\.mp4\z}, node.output['s3Key'])
    assert_equal 'video', node.output['type']
    assert_equal video_data.bytesize, node.output['size']
    refute_nil node.metadata['completed_at']
  end

  test "raises error when download fails" do
    pipeline = create(:video_production_pipeline)
    node = create(:video_production_node,
      pipeline:,
      status: 'in_progress',
      metadata: { process_uuid: 'test-uuid' })

    video_url = 'https://heygen.com/video/123.mp4'

    stub_request(:get, video_url).to_return(status: 404, body: 'Not Found')

    error = assert_raises(RuntimeError) do
      VideoProduction::APIs::Heygen::ProcessResult.(node.uuid, 'test-uuid', video_url)
    end

    assert_match(/Failed to download video from HeyGen/, error.message)
  end

  test "uses database lock when updating node" do
    pipeline = create(:video_production_pipeline)
    node = create(:video_production_node,
      pipeline:,
      status: 'in_progress',
      metadata: { process_uuid: 'test-uuid' })

    video_url = 'https://heygen.com/video/123.mp4'

    stub_request(:get, video_url).to_return(status: 200, body: 'video')
    Utils::S3::Upload.stubs(:call).returns("pipelines/#{pipeline.uuid}/nodes/#{node.uuid}/#{SecureRandom.uuid}.mp4")

    # Mock with_lock to verify it's called
    VideoProduction::Node.any_instance.expects(:with_lock).yields

    VideoProduction::APIs::Heygen::ProcessResult.(node.uuid, 'test-uuid', video_url)
  end
end
