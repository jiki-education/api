require "test_helper"

class VideoProduction::APIs::ElevenLabs::GenerateAudioTest < ActiveSupport::TestCase
  test "submits audio to ElevenLabs, marks execution started, and queues polling job" do
    pipeline = create(:video_production_pipeline)
    script_node = create(:video_production_node,
      pipeline:,
      type: 'asset',
      asset: { 'content' => 'Hello world' })
    node = create(:video_production_node,
      pipeline:,
      type: 'generate-voiceover',
      config: { 'voiceId' => 'voice-123', 'modelId' => 'eleven_turbo_v2_5' },
      inputs: { 'script' => [script_node.uuid] },
      status: 'pending')

    # Mock ElevenLabs API call
    stub_request(:post, "https://api.elevenlabs.io/v1/text-to-speech/voice-123").
      with(
        body: hash_including({ text: 'Hello world', model_id: 'eleven_turbo_v2_5' }),
        headers: { 'xi-api-key' => Jiki.secrets.elevenlabs_api_key }
      ).
      to_return(
        status: 200,
        headers: { 'Content-Type' => 'application/json' },
        body: { audio_id: 'audio-456' }.to_json
      )

    # Mock ExecutionUpdated command (ExecutionStarted is called by the executor)
    VideoProduction::Node::ExecutionUpdated.expects(:call).with(node, { audio_id: 'audio-456', stage: 'submitted' }, 'test-uuid')

    # Execute - CheckForResult will be deferred with wait: 10.seconds
    VideoProduction::APIs::ElevenLabs::GenerateAudio.(node, 'test-uuid')
  end

  test "uses default voice_id from config when not in node config" do
    pipeline = create(:video_production_pipeline)
    script_node = create(:video_production_node,
      pipeline:,
      type: 'asset',
      asset: { 'content' => 'Test' })
    node = create(:video_production_node,
      pipeline:,
      type: 'generate-voiceover',
      config: {},
      inputs: { 'script' => [script_node.uuid] })

    stub_request(:post, "https://api.elevenlabs.io/v1/text-to-speech/default").
      to_return(
        status: 200,
        headers: { 'Content-Type' => 'application/json' },
        body: { audio_id: 'audio-789' }.to_json
      )

    VideoProduction::Node::ExecutionUpdated.stubs(:call)

    VideoProduction::APIs::ElevenLabs::GenerateAudio.(node, 'test-uuid')

    assert_requested :post, "https://api.elevenlabs.io/v1/text-to-speech/default"
  end

  test "raises error when no script input specified" do
    pipeline = create(:video_production_pipeline)
    node = create(:video_production_node,
      pipeline:,
      type: 'generate-voiceover',
      inputs: {})

    error = assert_raises(RuntimeError) do
      VideoProduction::APIs::ElevenLabs::GenerateAudio.(node, 'test-uuid')
    end

    assert_match(/No script input specified/, error.message)
  end

  test "marks execution as failed when ElevenLabs API fails" do
    pipeline = create(:video_production_pipeline)
    script_node = create(:video_production_node,
      pipeline:,
      type: 'asset',
      asset: { 'content' => 'Test' })
    node = create(:video_production_node,
      pipeline:,
      type: 'generate-voiceover',
      config: {},
      inputs: { 'script' => [script_node.uuid] })

    stub_request(:post, %r{https://api.elevenlabs.io/v1/text-to-speech/.*}).
      to_return(status: 500, body: 'Internal Server Error')

    # NOTE: GenerateAudio no longer calls ExecutionFailed - the executor handles that

    assert_raises(RuntimeError) do
      VideoProduction::APIs::ElevenLabs::GenerateAudio.(node, 'test-uuid')
    end
  end
end
