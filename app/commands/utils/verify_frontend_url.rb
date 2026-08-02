class Utils::VerifyFrontendUrl
  include Mandate

  initialize_with :url

  # Additional frontend deployments that talk to this API, beyond the
  # canonical frontend_base_url. Kept in sync with config/initializers/cors.rb.
  ADDITIONAL_ALLOWED_ORIGINS = [
    "https://staging.jiki.io",
    "https://ihid.ngrok.dev"
  ].freeze

  def call
    return false if url.blank?

    uri = URI.parse(url)
    allowed_uris.any? do |allowed_uri|
      uri.scheme == allowed_uri.scheme &&
        uri.host == allowed_uri.host &&
        uri.port == allowed_uri.port
    end
  rescue URI::InvalidURIError
    false
  end

  private
  memoize
  def allowed_uris
    [Jiki.config.frontend_base_url, *ADDITIONAL_ALLOWED_ORIGINS].map { |u| URI.parse(u) }
  end
end
