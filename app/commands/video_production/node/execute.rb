class VideoProduction::Node::Execute
  include Mandate

  initialize_with :node

  def call
    # Run validation to update is_valid and validation_errors
    node.assign_attributes(VideoProduction::Node::Validate.(node))
    node.save!

    # Validate node is ready to execute
    raise VideoProductionBadInputsError, build_error_message unless node.ready_to_execute?

    # Get executor class for this node type
    executor_class = executor_class_for_type(node.type)

    # Queue the executor as a Sidekiq job
    executor_class.defer(node)

    node
  end

  private
  def executor_class_for_type(type)
    # Convert node type to class name: "merge-videos" -> "MergeVideos"
    class_name = type.split('-').map(&:capitalize).join

    # Build full class path
    full_class_name = "VideoProduction::Node::Executors::#{class_name}"

    # Constantize and return
    full_class_name.constantize
  rescue NameError
    raise VideoProductionBadInputsError, "No executor found for node type: #{type}"
  end

  def build_error_message
    errors = []

    errors << "Node must be in 'pending' or 'failed' status" unless node.status.in?(%w[pending failed])
    errors << "Node has validation errors: #{node.validation_errors}" unless node.is_valid?
    errors << "Input nodes are not all completed" unless node.inputs_satisfied?

    "Node is not ready to execute: #{errors.join(', ')}"
  end
end
