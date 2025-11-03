class VideoProduction::APIs::Heygen::ProcessResult
  include Mandate

  initialize_with :node_uuid, :process_uuid, :video_url

  def call
    # 1. Download video from HeyGen
    video_data = download_from_heygen!

    # 2. Upload to S3
    upload_to_s3!(video_data)

    # 3. Get metadata
    video_size = video_data.bytesize

    # 4. Build output hash
    output = {
      'type' => 'video',
      's3Key' => s3_key,
      'size' => video_size
    }

    # 5. Update node with output
    VideoProduction::Node::ExecutionSucceeded.(node, output, process_uuid)
  end

  private
  memoize
  def node = VideoProduction::Node.find_by!(uuid: node_uuid)

  memoize
  def s3_key = "pipelines/#{node.pipeline.uuid}/nodes/#{node_uuid}/#{SecureRandom.uuid}.mp4"

  def download_from_heygen!
    response = HTTParty.get(video_url)

    raise "Failed to download video from HeyGen: #{response.code} - #{response.body}" unless response.code == 200

    response.body
  end

  def upload_to_s3!(video_data)
    Utils::S3::Upload.(
      s3_key,
      video_data,
      'video/mp4',
      :video_production
    )
  end
end
