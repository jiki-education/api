require "test_helper"

class VideoProduction::Node::ExecutionUpdatedTest < ActiveSupport::TestCase
  test "updates node metadata" do
    pipeline = create(:video_production_pipeline)
    node = create(:video_production_node,
      pipeline:,
      status: 'in_progress',
      metadata: { process_uuid: 'test-uuid', started_at: 1.hour.ago.iso8601 })

    VideoProduction::Node::ExecutionUpdated.(node, { audio_id: 'audio-123', stage: 'submitted' }, 'test-uuid')

    node.reload
    assert_equal 'audio-123', node.metadata['audio_id']
    assert_equal 'submitted', node.metadata['stage']
    assert_equal 'test-uuid', node.metadata['process_uuid'] # Should preserve
  end

  test "uses database lock when updating node" do
    pipeline = create(:video_production_pipeline)
    node = create(:video_production_node,
      pipeline:,
      status: 'in_progress',
      metadata: { process_uuid: 'test-uuid' })

    VideoProduction::Node.any_instance.expects(:with_lock).yields

    VideoProduction::Node::ExecutionUpdated.(node, { test: 'value' }, 'test-uuid')
  end

  # Race Condition Tests
  test "does not update metadata when different execution is now running (second execution started)" do
    pipeline = create(:video_production_pipeline)
    node = create(:video_production_node,
      pipeline:,
      status: 'in_progress',
      metadata: { process_uuid: 'first-execution', started_at: 1.minute.ago.iso8601 })

    # Simulate: First execution is submitting to API, but before it updates metadata,
    # a second execution started and changed the process_uuid
    node.update!(metadata: { process_uuid: 'second-execution', started_at: Time.current.iso8601 })

    # First execution tries to update metadata with its old UUID
    VideoProduction::Node::ExecutionUpdated.(node, { audio_id: 'old-audio-123' }, 'first-execution')

    # Node metadata should NOT be updated with old audio_id
    node.reload
    assert_nil node.metadata['audio_id']
    assert_equal 'second-execution', node.metadata['process_uuid']
  end

  test "updates metadata when process_uuid matches current execution" do
    pipeline = create(:video_production_pipeline)
    node = create(:video_production_node,
      pipeline:,
      status: 'in_progress',
      metadata: { process_uuid: 'matching-uuid', started_at: 1.minute.ago.iso8601 })

    VideoProduction::Node::ExecutionUpdated.(node, { audio_id: 'audio-456', stage: 'processing' }, 'matching-uuid')

    node.reload
    assert_equal 'audio-456', node.metadata['audio_id']
    assert_equal 'processing', node.metadata['stage']
  end
end
