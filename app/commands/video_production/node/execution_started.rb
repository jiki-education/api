class VideoProduction::Node::ExecutionStarted
  include Mandate

  initialize_with :node, :metadata

  def call
    node.with_lock do
      node.update!(status: 'in_progress', metadata: new_metadata)
    end

    process_uuid
  end

  private
  memoize
  def process_uuid = SecureRandom.uuid

  def new_metadata
    (node.metadata || {}).merge(
      metadata.deep_stringify_keys.merge(
        'started_at' => Time.current.iso8601,
        'process_uuid' => process_uuid
      )
    )
  end
end
