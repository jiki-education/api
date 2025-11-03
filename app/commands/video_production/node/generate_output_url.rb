class VideoProduction::Node::GenerateOutputUrl
  include Mandate

  initialize_with :node

  def call
    # Extract S3 key from node
    s3_key = extract_s3_key
    raise NoOutputError, "Node has no output available" unless s3_key

    # Generate presigned URL (valid for 1 hour)
    Utils::S3::GeneratePresignedUrl.(
      s3_key,
      :video_production,
      expires_in: 1.hour.to_i
    )
  end

  private
  def extract_s3_key
    # For completed nodes with output
    return node.output['s3Key'] if node.output&.dig('s3Key')

    # For asset nodes with source
    return node.asset['source'] if node.type == 'asset' && node.asset&.dig('source')

    nil
  end

  class NoOutputError < StandardError; end
end
