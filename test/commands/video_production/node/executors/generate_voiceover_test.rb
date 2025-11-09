require "test_helper"

class VideoProduction::Node::Executors::GenerateVoiceoverTest < ActiveSupport::TestCase
  test "routes to ElevenLabs for elevenlabs provider" do
    pipeline = create(:video_production_pipeline)
    script_node = create(:video_production_node,
      pipeline:,
      type: 'asset',
      asset: { 'content' => 'Test script content' })

    node = create(:video_production_node,
      pipeline:,
      type: 'generate-voiceover',
      config: {
        'provider' => 'elevenlabs',
        'voiceId' => 'test-voice',
        'modelId' => 'eleven_turbo_v2_5'
      },
      inputs: { 'script' => [script_node.uuid] },
      status: 'pending')

    # Expect call to ElevenLabs API
    VideoProduction::APIs::ElevenLabs::GenerateAudio.expects(:call).with(
      node,
      instance_of(String) # process_uuid
    )

    VideoProduction::Node::Executors::GenerateVoiceover.(node)

    node.reload
    assert_equal 'in_progress', node.status
    refute_nil node.metadata['started_at']
    refute_nil node.metadata['process_uuid']
  end

  test "raises error for unknown provider" do
    pipeline = create(:video_production_pipeline)
    node = create(:video_production_node,
      pipeline:,
      type: 'generate-voiceover',
      config: { 'provider' => 'unknown-provider' },
      inputs: {},
      status: 'pending')

    error = assert_raises(RuntimeError) do
      VideoProduction::Node::Executors::GenerateVoiceover.(node)
    end

    assert_match(/Unknown voiceover provider: "unknown-provider"/, error.message)
    node.reload
    assert_equal 'failed', node.status
  end

  test "marks execution as failed when provider raises error" do
    pipeline = create(:video_production_pipeline)
    script_node = create(:video_production_node,
      pipeline:,
      type: 'asset',
      asset: { 'content' => 'Test script' })

    node = create(:video_production_node,
      pipeline:,
      type: 'generate-voiceover',
      config: {
        'provider' => 'elevenlabs',
        'voiceId' => 'test-voice'
      },
      inputs: { 'script' => [script_node.uuid] },
      status: 'pending')

    # Simulate provider error
    VideoProduction::APIs::ElevenLabs::GenerateAudio.expects(:call).raises(
      StandardError.new("ElevenLabs API error")
    )

    error = assert_raises(StandardError) do
      VideoProduction::Node::Executors::GenerateVoiceover.(node)
    end

    assert_equal "ElevenLabs API error", error.message
    node.reload
    assert_equal 'failed', node.status
    assert_equal "ElevenLabs API error", node.metadata['error']
    refute_nil node.metadata['completed_at']
  end

  test "marks execution as started before routing to provider" do
    pipeline = create(:video_production_pipeline)
    script_node = create(:video_production_node,
      pipeline:,
      type: 'asset',
      asset: { 'content' => 'Test script' })

    node = create(:video_production_node,
      pipeline:,
      type: 'generate-voiceover',
      config: {
        'provider' => 'elevenlabs',
        'voiceId' => 'test-voice'
      },
      inputs: { 'script' => [script_node.uuid] },
      status: 'pending')

    # Stub the API call
    VideoProduction::APIs::ElevenLabs::GenerateAudio.stubs(:call)

    VideoProduction::Node::Executors::GenerateVoiceover.(node)

    node.reload
    assert_equal 'in_progress', node.status
    refute_nil node.metadata['started_at']
    refute_nil node.metadata['process_uuid']
  end
end
