require "test_helper"

class VideoProduction::Node::ExecuteTest < ActiveSupport::TestCase
  test "executes merge-videos node and queues MergeVideos executor" do
    pipeline = create(:video_production_pipeline)
    input1 = create(:video_production_node, :completed, pipeline: pipeline, type: 'asset')
    input2 = create(:video_production_node, :completed, pipeline: pipeline, type: 'asset')
    node = create(:video_production_node,
      pipeline: pipeline,
      type: 'merge-videos',
      config: { 'provider' => 'ffmpeg' },
      inputs: { 'segments' => [input1.uuid, input2.uuid] },
      status: 'pending')

    VideoProduction::Node::Executors::MergeVideos.expects(:defer).with(node)

    result = VideoProduction::Node::Execute.(node)

    assert_equal node, result
  end

  test "executes generate-voiceover node and queues GenerateVoiceover executor" do
    pipeline = create(:video_production_pipeline)
    node = create(:video_production_node,
      pipeline: pipeline,
      type: 'generate-voiceover',
      config: { 'provider' => 'elevenlabs' },
      status: 'pending')

    VideoProduction::Node::Executors::GenerateVoiceover.expects(:defer).with(node)

    result = VideoProduction::Node::Execute.(node)

    assert_equal node, result
  end

  test "executes generate-talking-head node and queues GenerateTalkingHead executor" do
    pipeline = create(:video_production_pipeline)
    audio_node = create(:video_production_node, :completed, pipeline: pipeline, type: 'asset')
    node = create(:video_production_node,
      pipeline: pipeline,
      type: 'generate-talking-head',
      config: { 'provider' => 'heygen', 'avatarId' => 'test-avatar' },
      inputs: { 'audio' => audio_node.uuid },
      status: 'pending')

    VideoProduction::Node::Executors::GenerateTalkingHead.expects(:defer).with(node)

    result = VideoProduction::Node::Execute.(node)

    assert_equal node, result
  end

  test "raises error when node is not pending" do
    pipeline = create(:video_production_pipeline)
    node = create(:video_production_node,
      pipeline: pipeline,
      type: 'merge-videos',
      status: 'completed')

    error = assert_raises(VideoProductionBadInputsError) do
      VideoProduction::Node::Execute.(node)
    end

    assert_match(/not ready to execute/i, error.message)
    assert_match(/pending/i, error.message)
  end

  test "raises error when node is not valid" do
    pipeline = create(:video_production_pipeline)
    node = create(:video_production_node,
      pipeline: pipeline,
      type: 'merge-videos',
      status: 'pending',
      is_valid: false,
      validation_errors: { 'inputs' => ['segments is required'] })

    error = assert_raises(VideoProductionBadInputsError) do
      VideoProduction::Node::Execute.(node)
    end

    assert_match(/not ready to execute/i, error.message)
    assert_match(/validation errors/i, error.message)
  end

  test "raises error when inputs are not satisfied" do
    pipeline = create(:video_production_pipeline)
    input_node = create(:video_production_node,
      pipeline: pipeline,
      type: 'asset',
      status: 'pending')
    node = create(:video_production_node,
      pipeline: pipeline,
      type: 'merge-videos',
      inputs: { 'segments' => [input_node.uuid] },
      status: 'pending',
      is_valid: true)

    error = assert_raises(VideoProductionBadInputsError) do
      VideoProduction::Node::Execute.(node)
    end

    assert_match(/not ready to execute/i, error.message)
    assert_match(/input nodes/i, error.message)
  end

  test "raises error for unknown node type" do
    pipeline = create(:video_production_pipeline)
    node = create(:video_production_node,
      pipeline: pipeline,
      type: 'asset',
      status: 'pending',
      is_valid: true)

    error = assert_raises(VideoProductionBadInputsError) do
      VideoProduction::Node::Execute.(node)
    end

    assert_match(/no executor found/i, error.message)
    assert_match(/asset/i, error.message)
  end
end
