class VideoProduction::Node::ValidateInputs
  include Mandate

  initialize_with :node, :schema

  def call
    return {} if schema.nil?

    errors = {}
    errors.merge!(validate_unexpected_slots)
    errors.merge!(validate_each_slot)
    errors
  end

  private
  def validate_unexpected_slots
    errors = {}
    return errors if node.inputs.blank?

    # For empty schemas (like asset nodes), any inputs are unexpected
    if schema.empty?
      errors[:unexpected_inputs] = "#{node.type} nodes should not have inputs" if node.inputs.any?
      return errors
    end

    expected_slots = schema.keys.map(&:to_s)
    actual_slots = node.inputs.keys
    unexpected = actual_slots - expected_slots

    errors[:unexpected_inputs] = "Unexpected input slot(s): #{unexpected.join(', ')}" if unexpected.any?

    errors
  end

  def validate_each_slot
    errors = {}
    all_single_uuids = []
    single_slot_names = []

    schema.each do |slot_name, rules|
      value = node.inputs&.dig(slot_name)

      # Validate required
      if rules[:required] && value.blank?
        errors[slot_name.to_sym] = "is required for #{node.type} nodes"
        next
      end

      # Skip further validation if value is blank and not required
      next if value.blank?

      # Validate based on type
      case rules[:type]
      when :single
        # Check type but defer node reference validation to batch
        unless value.is_a?(String)
          errors[slot_name.to_sym] = "must be a single node UUID (string), not an array"
          next
        end
        all_single_uuids << value
        single_slot_names << slot_name
      when :multiple
        errors.merge!(validate_multiple_inputs(slot_name, value, rules))
      end
    end

    # Batch validate all single node references
    errors.merge!(validate_batch_single_references(single_slot_names, all_single_uuids)) if all_single_uuids.any?

    errors
  end

  def validate_batch_single_references(slot_names, uuids)
    errors = {}

    existing_uuids = VideoProduction::Node.where(
      pipeline_id: node.pipeline_id,
      uuid: uuids
    ).pluck(:uuid)

    invalid_uuids = uuids - existing_uuids

    if invalid_uuids.any?
      # Map invalid UUIDs back to their slot names
      slot_names.each_with_index do |slot_name, idx|
        uuid = uuids[idx]
        errors[slot_name.to_sym] = "references non-existent nodes: #{uuid}" if invalid_uuids.include?(uuid)
      end
    end

    errors
  end

  def validate_multiple_inputs(slot_name, value, rules)
    errors = {}

    # Must be an array
    unless value.is_a?(Array)
      errors[slot_name.to_sym] = "must be an array"
      return errors
    end

    # Validate min_count
    if rules[:min_count] && value.length < rules[:min_count]
      errors[slot_name.to_sym] = "requires at least #{rules[:min_count]} items, got #{value.length}"
      return errors
    end

    # Validate max_count
    if rules[:max_count] && value.length > rules[:max_count]
      errors[slot_name.to_sym] = "allows at most #{rules[:max_count]} items, got #{value.length}"
      return errors
    end

    # Validate node references exist
    errors.merge!(validate_node_references(slot_name, value))

    errors
  end

  def validate_node_references(slot_name, node_uuids)
    errors = {}

    existing_uuids = VideoProduction::Node.where(
      pipeline_id: node.pipeline_id,
      uuid: node_uuids
    ).pluck(:uuid)

    invalid_uuids = node_uuids - existing_uuids

    errors[slot_name.to_sym] = "references non-existent nodes: #{invalid_uuids.join(', ')}" if invalid_uuids.any?

    errors
  end
end
