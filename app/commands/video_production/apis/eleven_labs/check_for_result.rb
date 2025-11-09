class VideoProduction::APIs::ElevenLabs::CheckForResult < VideoProduction::APIs::CheckForResult
  # ElevenLabs-specific configuration
  MAX_ATTEMPTS = 60 # 60 attempts * 10 seconds = 10 minutes
  POLL_INTERVAL = 10.seconds

  # ElevenLabs API endpoint
  BASE_URL = 'https://api.elevenlabs.io/v1'.freeze

  protected
  # Check ElevenLabs API for job status
  # Returns: { status: 'completed'|'processing'|'failed', data: {...} }
  def check_api_status!
    # NOTE: ElevenLabs API might not have a status endpoint for all requests
    # This is a simplified example - actual implementation depends on API
    # For synchronous text-to-speech, the audio is returned immediately
    # For longer audio, they use a different async endpoint

    # audio_id is stored as external_id when job was submitted
    response = HTTParty.get(
      "#{BASE_URL}/text-to-speech/status/#{external_id}",
      headers: { 'xi-api-key' => Jiki.secrets.elevenlabs_api_key }
    )

    case response.code
    when 200
      api_data = response.parsed_response
      api_data = api_data.deep_symbolize_keys if api_data.is_a?(Hash)
      {
        status: api_data[:status] || 'completed',
        data: {
          audio_url: api_data[:audio_url],
          error: api_data[:error]
        }
      }
    when 404
      # Audio might be ready but status endpoint doesn't exist
      # Try direct download URL instead
      {
        status: 'completed',
        data: {
          audio_url: "#{BASE_URL}/text-to-speech/#{external_id}/audio"
        }
      }
    when 429
      # Rate limited - report as still processing, will retry
      { status: 'processing', data: {} }
    else
      raise "ElevenLabs status check failed: #{response.code} - #{response.body}"
    end
  end

  # Process the completed result from ElevenLabs
  def process_result!(data)
    VideoProduction::APIs::ElevenLabs::ProcessResult.(
      node.uuid,
      process_uuid,
      data[:audio_url]
    )
  end
end
