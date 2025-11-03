class VideoProduction::Node::Executors::MergeVideos
  include Mandate

  queue_as :video_production

  initialize_with :node

  def call
    # Initialize process_uuid to nil in case of early exception
    process_uuid = nil

    # 1. Mark node as started and get process_uuid
    process_uuid = VideoProduction::Node::ExecutionStarted.(node, {})

    # 2. Validate inputs
    validate_inputs!

    # 3. Invoke Lambda asynchronously
    # Lambda will callback to SPI endpoint when complete
    invoke_lambda!

    # NOTE: ExecutionSucceeded will be called via SPI callback
    # No need to wait for Lambda result here
  rescue StandardError => e
    VideoProduction::Node::ExecutionFailed.(node, e.message, process_uuid)
    raise
  end

  private
  def validate_inputs!
    segment_ids = node.inputs['segments'] || []
    raise "No segments specified" if segment_ids.empty?
    raise "At least 2 segments required" if segment_ids.length < 2

    # Validate all inputs have outputs
    ordered_inputs.each do |input_node|
      raise "Input node #{input_node&.id || 'unknown'} has no output" unless input_node&.output&.dig('s3Key')
    end
  end

  def invoke_lambda!
    payload = build_payload

    if ENV['INVOKE_LAMBDA_LOCALLY']
      # Development: Execute Lambda handler locally via Node.js
      VideoProduction::InvokeLambdaLocal.(lambda_function_name, payload)
    else
      # Production/Default: Execute via AWS Lambda SDK
      VideoProduction::InvokeLambda.(lambda_function_name, payload)
    end
  end

  def build_payload
    output_key = "pipelines/#{node.pipeline.uuid}/nodes/#{node.uuid}/output.mp4"

    {
      input_videos: input_urls,
      output_bucket: bucket,
      output_key: output_key,
      callback_url: callback_url,
      node_uuid: node.uuid,
      executor_type: 'merge-videos',
      process_uuid: node.metadata&.dig('process_uuid')
    }
  end

  def callback_url
    # Use spi_base_url from config (already includes /spi base path)
    # Development: http://local.jiki.io:3060/spi (configured via --add-host in bin/dev)
    # Production: actual SPI base URL
    "#{Jiki.config.spi_base_url}/video_production/executor_callback"
  end

  memoize
  def bucket
    Jiki.config.s3_bucket_video_production
  end

  memoize
  def ordered_inputs
    segment_ids = node.inputs['segments'] || []
    input_nodes = VideoProduction::Node.where(uuid: segment_ids).index_by(&:uuid)

    # Preserve order from inputs array
    segment_ids.map { |uuid| input_nodes[uuid] }
  end

  memoize
  def input_urls
    ordered_inputs.map do |input_node|
      "s3://#{bucket}/#{input_node.output['s3Key']}"
    end
  end

  def lambda_function_name
    # Get function name from environment or use default
    # In production this would be: jiki-video-merger-production
    env = ENV.fetch('RAILS_ENV', 'development')
    ENV.fetch('VIDEO_MERGER_LAMBDA_NAME', "jiki-video-merger-#{env}")
  end
end
