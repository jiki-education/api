class VideoProduction::APIs::Heygen::GenerateVideo
  include Mandate

  initialize_with :node, :process_uuid

  # HeyGen API endpoint
  BASE_URL = 'https://api.heygen.com'.freeze

  def call
    # 1. Submit to HeyGen API
    video_id = submit_to_heygen!(avatar_id, audio_asset_url, background_config, dimensions)

    # 2. Update metadata with video_id and stage (execution already started by executor)
    VideoProduction::Node::ExecutionUpdated.(node, { video_id: video_id, stage: 'submitted' }, process_uuid)

    # 3. Queue polling job to check for completion (start checking after 10 seconds)
    VideoProduction::APIs::Heygen::CheckForResult.defer(node, process_uuid, video_id, 1, wait: 10.seconds)
  end

  private
  memoize
  def avatar_id = node.config['avatarId'] || raise("avatarId is required in config")

  memoize
  def dimensions
    {
      width: node.config['width'] || 1280,
      height: node.config['height'] || 720
    }
  end

  memoize
  def audio_asset_url
    # Get audio from input node (should be an audio asset from ElevenLabs or other source)
    audio_node_ids = node.inputs['audio'] || []
    raise "No audio input specified" if audio_node_ids.empty?

    audio_node = VideoProduction::Node.find_by!(uuid: audio_node_ids.first)

    # Audio node should have output with s3Key
    s3_key = audio_node.output&.dig('s3Key')
    raise "Audio node has no s3Key in output" unless s3_key

    # Generate presigned URL for HeyGen to access the audio file
    Utils::S3::GeneratePresignedUrl.(s3_key, :video_production, expires_in: 1.hour)
  end

  memoize
  def background_config
    # Get background from input node (optional)
    background_node_ids = node.inputs['background'] || []
    return nil if background_node_ids.empty?

    background_node = VideoProduction::Node.find_by!(uuid: background_node_ids.first)

    # Background node should have output with s3Key (for uploaded images)
    s3_key = background_node.output&.dig('s3Key')
    return nil unless s3_key

    # Generate presigned URL for HeyGen to access the background image
    background_url = Utils::S3::GeneratePresignedUrl.(s3_key, :video_production, expires_in: 1.hour)

    {
      type: 'image',
      url: background_url
    }
  end

  def submit_to_heygen!(avatar_id, audio_url, background, dimensions)
    request_body = {
      dimension: dimensions,
      video_inputs: [
        {
          character: {
            type: 'avatar',
            avatar_id: avatar_id,
            avatar_style: 'normal'
          },
          voice: {
            type: 'audio',
            audio_url: audio_url
          }
        }
      ]
    }

    # Add background if provided
    request_body[:video_inputs][0][:background] = background if background

    response = HTTParty.post(
      "#{BASE_URL}/v2/video/generate",
      headers: {
        'X-Api-Key' => Jiki.secrets.heygen_api_key,
        'Content-Type' => 'application/json'
      },
      body: request_body.to_json
    )

    case response.code
    when 200
      response_data = response.parsed_response
      raise "HeyGen API returned unexpected response format" unless response_data.is_a?(Hash)

      video_id = response_data.dig('data', 'video_id')
      raise "HeyGen API returned success but no video_id in response" unless video_id

      video_id

    when 429
      retry_after = response.headers['retry-after']&.to_i || 60
      raise "HeyGen rate limit, retry after #{retry_after} seconds"
    else
      raise "HeyGen API error: #{response.code} - #{response.body}"
    end
  end
end
