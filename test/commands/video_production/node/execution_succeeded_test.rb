require "test_helper"

class VideoProduction::Node::ExecutionSucceededTest < ActiveSupport::TestCase
  test "updates node to completed status with output" do
    pipeline = create(:video_production_pipeline)
    node = create(:video_production_node,
      pipeline:,
      status: 'in_progress',
      metadata: { process_uuid: 'test-uuid', started_at: 1.hour.ago.iso8601 })

    output = {
      type: 'audio',
      s3_key: 'pipelines/123/audio.mp3',
      duration: 120,
      size: 1024
    }

    VideoProduction::Node::ExecutionSucceeded.(node, output, 'test-uuid')

    node.reload
    assert_equal 'completed', node.status
    assert_equal output.stringify_keys, node.output
    refute_nil node.metadata['completed_at']
    refute_nil node.metadata['started_at'] # Should preserve existing metadata
  end

  test "uses database lock when updating node" do
    pipeline = create(:video_production_pipeline)
    node = create(:video_production_node,
      pipeline:,
      status: 'in_progress',
      metadata: { process_uuid: 'test-uuid' })

    output = { type: 'video', s3_key: 'test.mp4', duration: 60, size: 2048 }

    VideoProduction::Node.any_instance.expects(:with_lock).yields

    VideoProduction::Node::ExecutionSucceeded.(node, output, 'test-uuid')
  end

  # Race Condition Tests
  test "does not update node when different execution is now running (second execution started)" do
    pipeline = create(:video_production_pipeline)
    node = create(:video_production_node,
      pipeline:,
      status: 'in_progress',
      metadata: { process_uuid: 'first-execution', started_at: 1.minute.ago.iso8601 })

    # Simulate: First execution job completes, but before it updates the node,
    # a second execution started and changed the process_uuid
    node.update!(metadata: { process_uuid: 'second-execution', started_at: Time.current.iso8601 })

    # First execution tries to mark as succeeded with its old UUID
    output = { type: 'audio', s3_key: 'old-output.mp3', duration: 10.5 }

    # This should NOT update the node because process_uuid doesn't match
    VideoProduction::Node::ExecutionSucceeded.(node, output, 'first-execution')

    # Node should still be in_progress for the second execution
    node.reload
    assert_equal 'in_progress', node.status
    assert_nil node.output # Not updated with old output
    assert_equal 'second-execution', node.metadata['process_uuid']
  end

  test "updates node when process_uuid matches current execution" do
    pipeline = create(:video_production_pipeline)
    node = create(:video_production_node,
      pipeline:,
      status: 'in_progress',
      metadata: { process_uuid: 'matching-uuid', started_at: 1.minute.ago.iso8601 })

    output = { 'type' => 'audio', 's3Key' => 'correct-output.mp3', 'duration' => 10.5 }

    # This should succeed because UUID matches
    VideoProduction::Node::ExecutionSucceeded.(node, output, 'matching-uuid')

    node.reload
    assert_equal 'completed', node.status
    assert_equal 'correct-output.mp3', node.output['s3Key']
  end
end
