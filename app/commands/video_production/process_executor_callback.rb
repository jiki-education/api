class VideoProduction::ProcessExecutorCallback
  include Mandate

  initialize_with :node, :executor_type, result: nil, error: nil, error_type: nil, process_uuid: nil

  class StaleCallbackError < StandardError; end

  def call
    # Check if this is a stale callback (process_uuid doesn't match)
    # This can happen if:
    # 1. A new execution started after this Lambda was invoked
    # 2. This is a retry of an old callback
    return handle_stale_callback unless process_uuid_matches?

    if error.present?
      handle_error
    else
      handle_success
    end
  end

  private
  memoize
  def current_process_uuid
    node.metadata&.dig('process_uuid')
  end

  def process_uuid_matches?
    # No process_uuid in metadata means execution never started - stale
    return false unless current_process_uuid.present?

    # If callback includes process_uuid, validate it matches current execution
    return false if process_uuid.present? && process_uuid != current_process_uuid

    # Node must be in_progress (not completed/failed by another execution)
    node.status == 'in_progress'
  end

  def handle_stale_callback
    Rails.logger.warn(
      "[VideoProduction] Stale callback ignored for node #{node.uuid}: " \
      "current status=#{node.status}, current process_uuid=#{current_process_uuid}, " \
      "callback process_uuid=#{process_uuid || 'not provided'}"
    )
    raise StaleCallbackError, "Callback ignored - node status is #{node.status} or process_uuid mismatch"
  end

  def handle_success
    Rails.logger.info("[VideoProduction] Processing successful callback for node #{node.uuid}")

    VideoProduction::Node::ExecutionSucceeded.(
      node,
      build_output(result),
      current_process_uuid # Pass current process_uuid for validation
    )
  end

  def handle_error
    Rails.logger.error(
      "[VideoProduction] Processing error callback for node #{node.uuid}: " \
      "#{error_type || 'unknown'} - #{error}"
    )

    VideoProduction::Node::ExecutionFailed.(
      node,
      error,
      current_process_uuid # Pass current process_uuid for validation
    )
  end

  def build_output(result)
    return {} unless result.is_a?(Hash)

    case executor_type
    when 'merge-videos'
      {
        'type' => 'video',
        's3Key' => result['s3_key'] || result[:s3_key],
        'duration' => result['duration'] || result[:duration] || 0,
        'size' => result['size'] || result[:size] || 0
      }
    else
      # Generic output format
      result.transform_keys(&:to_s)
    end
  end
end
