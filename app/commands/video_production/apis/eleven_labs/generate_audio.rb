class VideoProduction::APIs::ElevenLabs::GenerateAudio
  include Mandate

  initialize_with :node, :process_uuid

  # ElevenLabs API endpoint
  BASE_URL = 'https://api.elevenlabs.io/v1'.freeze

  def call
    # 1. Submit to ElevenLabs API
    audio_id = submit_to_elevenlabs!(voice_id, model_id, script_text)

    # 2. Update metadata with audio_id and stage (execution already started by executor)
    VideoProduction::Node::ExecutionUpdated.(node, { audio_id: audio_id, stage: 'submitted' }, process_uuid)

    # 3. Queue polling job to check for completion (start checking after 10 seconds)
    VideoProduction::APIs::ElevenLabs::CheckForResult.defer(node, process_uuid, audio_id, 1, wait: 10.seconds)
  end

  private
  memoize
  def voice_id = node.config['voiceId'] || 'default'

  memoize
  def model_id = node.config['modelId'] || 'eleven_turbo_v2_5'

  memoize
  def script_text
    # Get script from input node (asset node containing text)
    script_node_ids = node.inputs['script'] || []
    raise "No script input specified" if script_node_ids.empty?

    script_node = VideoProduction::Node.find_by!(uuid: script_node_ids.first)

    # For asset nodes, script is in asset.source or asset.content
    script_node.asset['content'] || script_node.asset['source'] || ''
  end

  def submit_to_elevenlabs!(voice_id, model_id, text)
    response = HTTParty.post(
      "#{BASE_URL}/text-to-speech/#{voice_id}",
      headers: {
        'xi-api-key' => Jiki.secrets.elevenlabs_api_key,
        'Content-Type' => 'application/json'
      },
      body: {
        text: text,
        model_id: model_id,
        voice_settings: {
          stability: node.config['stability'] || 0.5,
          similarity_boost: node.config['similarityBoost'] || 0.75
        }
      }.to_json
    )

    case response.code
    when 200
      # ElevenLabs returns audio data directly for synchronous requests
      # For long-form audio, they return a job ID
      response_data = response.parsed_response
      raise "ElevenLabs API returned unexpected response format" unless response_data.is_a?(Hash)

      audio_id = response_data.deep_symbolize_keys[:audio_id]
      raise "ElevenLabs API returned success but no audio_id in response" unless audio_id

      audio_id

    when 429
      retry_after = response.headers['retry-after']&.to_i || 60
      raise "ElevenLabs rate limit, retry after #{retry_after} seconds"
    else
      raise "ElevenLabs API error: #{response.code} - #{response.body}"
    end
  end
end
