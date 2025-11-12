module Auth
  class VerifyGoogleToken
    include Mandate

    initialize_with :token

    def call
      raise InvalidGoogleTokenError, "Invalid Google token" unless payload
      raise InvalidGoogleTokenError, "Token expired" if Time.zone.at(payload['exp']) < Time.zone.now

      payload
    rescue GoogleIDToken::ValidationError => e
      raise InvalidGoogleTokenError, "Google token validation failed: #{e.message}"
    end

    private
    memoize
    def payload = validator.check(token, google_oauth_client_id)

    memoize
    def validator = GoogleIDToken::Validator.new

    memoize
    def google_oauth_client_id = Jiki.secrets.google_oauth_client_id
  end
end
