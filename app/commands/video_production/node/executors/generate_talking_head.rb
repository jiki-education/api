class VideoProduction::Node::Executors::GenerateTalkingHead
  include Mandate

  queue_as :video_production

  initialize_with :node

  def call
    # Initialize process_uuid to nil in case of early exception
    process_uuid = nil

    # 1. Mark execution as started and get process_uuid
    process_uuid = VideoProduction::Node::ExecutionStarted.(node, {})

    # 2. Route to the appropriate provider based on node provider
    case node.provider
    when 'heygen'
      VideoProduction::APIs::Heygen::GenerateVideo.(node, process_uuid)
    else
      raise "Unknown talking head provider: #{node.provider.inspect}"
    end
  rescue StandardError => e
    VideoProduction::Node::ExecutionFailed.(node, e.message, process_uuid)
    raise
  end
end
