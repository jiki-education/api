require "test_helper"

class VideoProduction::Node::ExecutionStartedTest < ActiveSupport::TestCase
  test "marks node as in_progress with started_at timestamp" do
    pipeline = create(:video_production_pipeline)
    node = create(:video_production_node, pipeline:, status: 'pending')

    freeze_time do
      VideoProduction::Node::ExecutionStarted.(node, {})

      node.reload
      assert_equal 'in_progress', node.status
      assert_equal Time.current.iso8601, node.metadata['started_at']
    end
  end

  test "merges additional metadata fields" do
    pipeline = create(:video_production_pipeline)
    node = create(:video_production_node, pipeline:, status: 'pending')

    VideoProduction::Node::ExecutionStarted.(node, { audio_id: 'test-123', stage: 'submitted' })

    node.reload
    assert_equal 'in_progress', node.status
    assert_equal 'test-123', node.metadata['audio_id']
    assert_equal 'submitted', node.metadata['stage']
    assert node.metadata['started_at'].present?
  end

  test "preserves existing metadata fields" do
    pipeline = create(:video_production_pipeline)
    node = create(:video_production_node,
      pipeline:,
      status: 'pending',
      metadata: { 'existing_field' => 'existing_value' })

    VideoProduction::Node::ExecutionStarted.(node, { new_field: 'new_value' })

    node.reload
    assert_equal 'existing_value', node.metadata['existing_field']
    assert_equal 'new_value', node.metadata['new_field']
  end

  test "uses database lock to prevent race conditions" do
    pipeline = create(:video_production_pipeline)
    node = create(:video_production_node, pipeline:, status: 'pending')

    # Mock with_lock to verify it's called
    VideoProduction::Node.any_instance.expects(:with_lock).yields

    VideoProduction::Node::ExecutionStarted.(node, {})
  end

  # Race Condition Tests
  test "generates and stores process_uuid to track this execution" do
    pipeline = create(:video_production_pipeline)
    node = create(:video_production_node, pipeline:, status: 'pending')

    # Mock SecureRandom to return a predictable UUID
    SecureRandom.expects(:uuid).returns('generated-uuid-123')

    process_uuid = VideoProduction::Node::ExecutionStarted.(node, { audio_id: 'test' })

    node.reload
    assert_equal 'generated-uuid-123', node.metadata['process_uuid']
    assert_equal 'generated-uuid-123', process_uuid # Should return the UUID
  end

  test "returns process_uuid so caller can track execution" do
    pipeline = create(:video_production_pipeline)
    node = create(:video_production_node, pipeline:, status: 'pending')

    # The command should return the process_uuid
    result = VideoProduction::Node::ExecutionStarted.(node, {})

    assert result.is_a?(String)
    assert_equal 36, result.length # UUID format
    assert_equal result, node.reload.metadata['process_uuid']
  end

  test "generates new process_uuid for each execution" do
    pipeline = create(:video_production_pipeline)
    node = create(:video_production_node, pipeline:, status: 'pending')

    # First execution
    first_uuid = VideoProduction::Node::ExecutionStarted.(node, {})
    assert_equal first_uuid, node.reload.metadata['process_uuid']

    # Node goes back to pending (e.g., after completion or failure)
    node.update!(status: 'pending')

    # Second execution should get a different UUID
    second_uuid = VideoProduction::Node::ExecutionStarted.(node, {})
    assert_equal second_uuid, node.reload.metadata['process_uuid']

    # The two UUIDs should be different
    refute_equal first_uuid, second_uuid
  end
end
