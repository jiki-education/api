class LLM::Exec
  include Mandate
  include HTTParty

  initialize_with :service, :model, :prompt, :spi_endpoint, additional_params: {}, stream_channel: nil

  def call
    validate!

    response = self.class.post(
      llm_proxy_url,
      body: payload.to_json,
      headers: { 'Content-Type' => 'application/json' },
      timeout: 10 # 10 seconds timeout for initial response
    )

    raise "LLM proxy request failed with status #{response.code}: #{response.body}" unless response.success?

    response
  end

  private
  def validate!
    raise ArgumentError, "service is required" if service.blank?
    raise ArgumentError, "model is required" if model.blank?
    raise ArgumentError, "prompt is required" if prompt.blank?
    raise ArgumentError, "spi_endpoint is required" if spi_endpoint.blank?
  end

  memoize
  def llm_proxy_url = Jiki.config.llm_proxy_url

  memoize
  def payload
    {
      service: service.to_s,
      model: model.to_s,
      prompt:,
      spi_endpoint: "llm/#{spi_endpoint}",
      stream_channel:
    }.merge(additional_params || {}).compact
  end
end
