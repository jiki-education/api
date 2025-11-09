# Base class for polling external APIs
#
# Subclasses must implement:
# - check_api_status() - returns { state:, result_url:, error: }
# - process_result(result_url) - downloads and processes the result
#
# Usage:
#   class MyAPI::CheckForResult < VideoProduction::APIs::CheckForResult
#     def check_api_status
#       # Call API, return { state: 'completed'|'processing'|'failed', result_url:, error: }
#     end
#
#     def process_result(result_url)
#       # Download from result_url, upload to S3, return { s3_key:, duration:, size: }
#     end
#   end
class VideoProduction::APIs::CheckForResult
  include Mandate

  queue_as :video_production

  initialize_with :node, :process_uuid, :external_id, :attempt

  # Override these in subclasses
  MAX_ATTEMPTS = 60
  POLL_INTERVAL = 10.seconds

  def call
    # 0. Verify this is still the current execution (not a stale job)
    node.reload
    unless node.status == 'in_progress' && node.process_uuid == process_uuid
      # Silently exit - either webhook already processed, node failed, or new execution started
      return
    end

    # 1. Check if we've exceeded max attempts
    if attempt > max_attempts
      VideoProduction::Node::ExecutionFailed.(node, "Polling timeout after #{max_attempts} attempts", process_uuid)
      return
    end

    # 2. Check API for status (implemented by subclass)
    # Returns: { status: 'completed'|'processing'|'failed', data: {...} }
    response = check_api_status!

    case response[:status]
    when 'completed'
      # 3a. Process result (implemented by subclass)
      # process_result! handles downloading, uploading to S3, and updating the node
      process_result!(response[:data])

    when 'failed'
      # 3b. Mark node as failed
      error_message = response[:data]&.dig(:error) || 'Unknown error'
      VideoProduction::Node::ExecutionFailed.(node, "API generation failed: #{error_message}", process_uuid)

    when 'processing', 'pending'
      # 3c. Still processing - reschedule polling job
      self.class.defer(node, process_uuid, external_id, attempt + 1, wait: poll_interval)

    else
      raise "Unknown API status: #{response[:status]}"
    end
  rescue StandardError => e
    VideoProduction::Node::ExecutionFailed.(node, "Polling error: #{e.message}", process_uuid)
    raise
  end

  protected
  # Override these methods in subclasses
  #
  # check_api_status! should return:
  #   { status: 'completed'|'processing'|'failed', data: { ... } }
  #
  # The data hash should contain all information needed by process_result!
  def check_api_status!
    raise NotImplementedError, "Subclass must implement #check_api_status!"
  end

  # process_result! receives the data hash from check_api_status!
  # It should:
  # 1. Download the result from the external API
  # 2. Upload to S3
  # 3. Update the node with output (calls update_node_output)
  #
  # This method should not return anything - it updates the node directly
  def process_result!(data)
    raise NotImplementedError, "Subclass must implement #process_result!"
  end

  # Subclasses can override these for different polling behavior
  def max_attempts
    self.class::MAX_ATTEMPTS
  end

  def poll_interval
    self.class::POLL_INTERVAL
  end
end
