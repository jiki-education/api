class VideoProduction::APIs::Heygen::CheckForResult < VideoProduction::APIs::CheckForResult
  # HeyGen-specific configuration
  MAX_ATTEMPTS = 60 # 60 attempts * 10 seconds = 10 minutes
  POLL_INTERVAL = 10.seconds

  # HeyGen API endpoint
  BASE_URL = 'https://api.heygen.com'.freeze

  protected
  # Check HeyGen API for video status
  # Returns: { status: 'completed'|'processing'|'pending'|'failed', data: {...} }
  def check_api_status!
    # video_id is stored as external_id when job was submitted
    response = HTTParty.get(
      "#{BASE_URL}/v1/video_status.get",
      headers: { 'X-Api-Key' => Jiki.secrets.heygen_api_key },
      query: { video_id: external_id }
    )

    case response.code
    when 200
      api_data = response.parsed_response
      api_data = api_data.deep_symbolize_keys if api_data.is_a?(Hash)

      # HeyGen response format: { data: { status: '...', video_url: '...', ... } }
      data = api_data[:data] || {}
      heygen_status = data[:status]

      # Map HeyGen status to our internal status
      case heygen_status
      when 'completed'
        status = 'completed'
      when 'processing', 'pending'
        status = 'processing'
      when 'failed'
        status = 'failed'
      else
        status = raise "Unknown HeyGen status: #{heygen_status}"
      end

      {
        status: status,
        data: {
          video_url: data[:video_url],
          thumbnail_url: data[:thumbnail_url],
          error: data[:error]
        }
      }
    when 429
      # Rate limited - report as still processing, will retry
      { status: 'processing', data: {} }
    else
      raise "HeyGen status check failed: #{response.code} - #{response.body}"
    end
  end

  # Process the completed result from HeyGen
  def process_result!(data)
    VideoProduction::APIs::Heygen::ProcessResult.(
      node.uuid,
      process_uuid,
      data[:video_url]
    )
  end
end
