class VideoProduction::Node::ExecutionUpdated
  include Mandate

  initialize_with :node, :metadata, :process_uuid

  def call
    node.with_lock do
      # Verify this execution still owns the node (not a stale job)
      return unless node.process_uuid == process_uuid

      node.update!(metadata: new_metadata)
    end
  end

  private
  def new_metadata
    (node.metadata || {}).merge(metadata)
  end
end
