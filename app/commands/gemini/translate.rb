class Gemini::Translate
  include Mandate
  include HTTParty

  base_uri 'https://generativelanguage.googleapis.com'

  initialize_with :prompt, model: :flash

  def call
    validate!

    response = self.class.post(
      api_endpoint,
      body: request_payload.to_json,
      headers: {
        'Content-Type' => 'application/json',
        'x-goog-api-key' => api_key
      },
      timeout: 60 # 60 seconds for LLM response
    )

    handle_response(response)
  end

  private
  def validate!
    raise ArgumentError, "prompt is required" if prompt.blank?
    raise ArgumentError, "google_api_key secret is required" if api_key.blank?
    raise ArgumentError, "model must be :flash or :pro" unless %i[flash pro].include?(model)
  end

  memoize
  def api_key = Jiki.secrets.google_api_key

  memoize
  def model_name
    case model
    when :flash then 'gemini-2.5-flash'
    when :pro then 'gemini-2.5-pro'
    end
  end

  memoize
  def api_endpoint = "/v1beta/models/#{model_name}:generateContent"

  memoize
  def request_payload
    {
      contents: [{
        parts: [{ text: prompt }]
      }],
      generationConfig: {
        responseMimeType: "application/json",
        responseSchema: {
          type: "object",
          properties: {
            subject: { type: "string" },
            body_mjml: { type: "string" },
            body_text: { type: "string" }
          },
          required: %w[subject body_mjml body_text]
        },
        thinkingConfig: {
          thinkingBudget: 0 # Disable thinking for faster responses
        }
      }
    }
  end

  def handle_response(response)
    case response.code
    when 200
      parse_successful_response(response)
    when 429
      raise Gemini::RateLimitError, "Rate limit exceeded. Response: #{response.body}"
    when 400
      raise Gemini::InvalidRequestError, "Invalid request. Response: #{response.body}"
    else
      raise Gemini::APIError, "API request failed with status #{response.code}. Response: #{response.body}"
    end
  end

  def parse_successful_response(response)
    body = JSON.parse(response.body, symbolize_names: true)

    # Extract the text from Gemini's response structure
    # Response format: { candidates: [{ content: { parts: [{ text: "..." }] } }] }
    text = body.dig(:candidates, 0, :content, :parts, 0, :text)

    raise Gemini::APIError, "No text in response: #{response.body}" if text.blank?

    # Parse the JSON response from the LLM (which should contain subject, body_mjml, body_text)
    JSON.parse(text, symbolize_names: true)
  rescue JSON::ParserError => e
    raise Gemini::InvalidRequestError, "Failed to parse LLM response as JSON: #{e.message}. Response: #{text}"
  end
end
