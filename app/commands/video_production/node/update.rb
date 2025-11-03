class VideoProduction::Node::Update
  include Mandate

  initialize_with :node, :attributes

  def call
    node.assign_attributes(attributes)
    node.assign_attributes(VideoProduction::Node::Validate.(node))
    node[:status] = 'pending' if should_reset_status?

    node.save!
    node
  end

  private
  def should_reset_status?
    # Reset to pending if structure changed (not title)
    structure_keys = %w[inputs config asset]
    (node.changes.keys & structure_keys).present?
  end
end
