class VideoProduction::Node::ExecutionFailed
  include Mandate

  initialize_with :node, :error_message, :process_uuid

  def call
    node.with_lock do
      # Verify this execution still owns the node (not a stale job)
      # Only fail if this execution's UUID matches the node's current process_uuid
      return unless node.process_uuid == process_uuid

      node.update!(status: 'failed', metadata: new_metadata)
    end
  end

  private
  def new_metadata
    (node.metadata || {}).merge(
      'error' => error_message,
      'completed_at' => Time.current.iso8601
    )
  end
end
