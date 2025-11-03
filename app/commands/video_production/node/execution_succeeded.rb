class VideoProduction::Node::ExecutionSucceeded
  include Mandate

  initialize_with :node, :output_hash, :process_uuid

  def call
    node.with_lock do
      # Verify this execution still owns the node (not a stale job)
      return unless node.process_uuid == process_uuid

      node.update!(
        status: 'completed',
        output: output_hash,
        metadata: new_metadata
      )
    end
  end

  private
  def new_metadata
    (node.metadata || {}).merge(
      completed_at: Time.current.iso8601
    )
  end
end
