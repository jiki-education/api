class VideoProduction::Node::Destroy
  include Mandate

  initialize_with :node

  def call
    ActiveRecord::Base.transaction do
      cleanup_references!
      node.destroy!
    end
  end

  private
  def cleanup_references!
    # Find all nodes in pipeline that might reference this node's UUID
    nodes_to_update = VideoProduction::Node.
      where(pipeline_id: node.pipeline_id).
      where("inputs::text LIKE ?", "%#{node.uuid}%")

    nodes_to_update.each do |other_node|
      cleaned_inputs = remove_node_references(other_node.inputs, node.uuid)
      next if cleaned_inputs == other_node.inputs

      other_node.update_column(:inputs, cleaned_inputs)
    end
  end

  def remove_node_references(inputs, uuid_to_remove)
    inputs.transform_values do |value|
      case value
      when String
        value == uuid_to_remove ? nil : value
      when Array
        value.reject { |v| v == uuid_to_remove }
      else
        value
      end
    end.compact
  end
end
