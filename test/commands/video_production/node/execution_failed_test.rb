require "test_helper"

class VideoProduction::Node::ExecutionFailedTest < ActiveSupport::TestCase
  test "marks node as failed with error message and completed_at timestamp" do
    pipeline = create(:video_production_pipeline)
    node = create(:video_production_node,
      pipeline:,
      status: 'in_progress',
      metadata: { process_uuid: 'test-uuid' })

    freeze_time do
      VideoProduction::Node::ExecutionFailed.(node, "Something went wrong", 'test-uuid')

      node.reload
      assert_equal 'failed', node.status
      assert_equal 'Something went wrong', node.metadata['error']
      assert_equal Time.current.iso8601, node.metadata['completed_at']
    end
  end

  test "preserves existing metadata fields" do
    pipeline = create(:video_production_pipeline)
    node = create(:video_production_node,
      pipeline:,
      status: 'in_progress',
      metadata: { 'process_uuid' => 'test-uuid', 'started_at' => '2024-10-19T10:00:00Z', 'audio_id' => 'test-123' })

    VideoProduction::Node::ExecutionFailed.(node, "API error", 'test-uuid')

    node.reload
    assert_equal '2024-10-19T10:00:00Z', node.metadata['started_at']
    assert_equal 'test-123', node.metadata['audio_id']
    assert_equal 'API error', node.metadata['error']
  end

  test "uses database lock to prevent race conditions" do
    pipeline = create(:video_production_pipeline)
    node = create(:video_production_node,
      pipeline:,
      status: 'in_progress',
      metadata: { process_uuid: 'test-uuid' })

    # Mock with_lock to verify it's called
    VideoProduction::Node.any_instance.expects(:with_lock).yields

    VideoProduction::Node::ExecutionFailed.(node, "Test error", 'test-uuid')
  end

  # Race Condition Tests
  test "does not update node when different execution is now running (second execution started)" do
    pipeline = create(:video_production_pipeline)
    node = create(:video_production_node,
      pipeline:,
      status: 'in_progress',
      metadata: { process_uuid: 'first-execution', started_at: 1.minute.ago.iso8601 })

    # Simulate: First execution encounters an error, but before it marks as failed,
    # a second execution started and changed the process_uuid
    node.update!(metadata: { process_uuid: 'second-execution', started_at: Time.current.iso8601 })

    # First execution tries to mark as failed with its old UUID
    VideoProduction::Node::ExecutionFailed.(node, "Timeout error", 'first-execution')

    # Node should still be in_progress for the second execution (not marked as failed)
    node.reload
    assert_equal 'in_progress', node.status
    assert_nil node.metadata['error'] # Not updated with old error
    assert_equal 'second-execution', node.metadata['process_uuid']
  end

  test "updates node when process_uuid matches current execution" do
    pipeline = create(:video_production_pipeline)
    node = create(:video_production_node,
      pipeline:,
      status: 'in_progress',
      metadata: { process_uuid: 'matching-uuid', started_at: 1.minute.ago.iso8601 })

    # This should succeed because UUID matches
    VideoProduction::Node::ExecutionFailed.(node, "Valid error", 'matching-uuid')

    node.reload
    assert_equal 'failed', node.status
    assert_equal 'Valid error', node.metadata['error']
  end

  test "does not update node when process_uuid is nil (execution never started)" do
    pipeline = create(:video_production_pipeline)
    node = create(:video_production_node,
      pipeline:,
      status: 'in_progress',
      metadata: { process_uuid: 'current-execution', started_at: Time.current.iso8601 })

    # Simulate: Exception before ExecutionStarted completes (process_uuid = nil in executor)
    # This should NOT fail the node since another execution is running
    VideoProduction::Node::ExecutionFailed.(node, "Early error", nil)

    node.reload
    assert_equal 'in_progress', node.status
    assert_nil node.metadata['error']
    assert_equal 'current-execution', node.metadata['process_uuid']
  end
end
