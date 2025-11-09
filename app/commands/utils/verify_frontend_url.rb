class Utils::VerifyFrontendUrl
  include Mandate

  initialize_with :url

  def call
    return false if url.blank?

    # Parse both URLs
    uri = URI.parse(url)
    allowed_uri = URI.parse(Jiki.config.frontend_base_url)

    # Check scheme, host, and port match exactly
    uri.scheme == allowed_uri.scheme &&
      uri.host == allowed_uri.host &&
      uri.port == allowed_uri.port
  rescue URI::InvalidURIError
    false
  end
end
