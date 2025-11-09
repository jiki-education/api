require "test_helper"

class VideoProduction::Node::Executors::GenerateTalkingHeadTest < ActiveSupport::TestCase
  test "routes to Heygen provider" do
    pipeline = create(:video_production_pipeline)
    audio_node = create(:video_production_node,
      pipeline:,
      output: { 's3Key' => 'audio.mp3' })
    node = create(:video_production_node,
      pipeline:,
      type: 'generate-talking-head',
      config: { 'provider' => 'heygen', 'avatarId' => 'test-avatar' },
      inputs: { 'audio' => [audio_node.uuid] })

    # Mock ExecutionStarted to return a process_uuid
    VideoProduction::Node::ExecutionStarted.expects(:call).with(node, {}).returns('test-process-uuid')

    # Mock the Heygen API call
    VideoProduction::APIs::Heygen::GenerateVideo.expects(:call).with(node, 'test-process-uuid')

    VideoProduction::Node::Executors::GenerateTalkingHead.(node)
  end

  test "raises error for unknown provider" do
    pipeline = create(:video_production_pipeline)
    node = create(:video_production_node,
      pipeline:,
      type: 'generate-talking-head',
      config: { 'provider' => 'unknown-provider' })

    VideoProduction::Node::ExecutionStarted.stubs(:call).returns('test-uuid')
    VideoProduction::Node::ExecutionFailed.expects(:call).with do |n, msg, uuid|
      n == node && msg.include?('Unknown talking head provider') && uuid == 'test-uuid'
    end

    assert_raises(RuntimeError) do
      VideoProduction::Node::Executors::GenerateTalkingHead.(node)
    end
  end

  test "marks execution as failed when exception occurs" do
    pipeline = create(:video_production_pipeline)
    node = create(:video_production_node,
      pipeline:,
      type: 'generate-talking-head',
      config: { 'provider' => 'heygen', 'avatar_id' => 'test' })

    VideoProduction::Node::ExecutionStarted.stubs(:call).returns('test-uuid')
    VideoProduction::APIs::Heygen::GenerateVideo.stubs(:call).raises(StandardError.new("API connection failed"))

    VideoProduction::Node::ExecutionFailed.expects(:call).with(node, "API connection failed", 'test-uuid')

    assert_raises(StandardError) do
      VideoProduction::Node::Executors::GenerateTalkingHead.(node)
    end
  end
end
