module Auth
  class VerifyGoogleToken
    include Mandate

    initialize_with :token

    def call
      validator = GoogleIDToken::Validator.new
      payload = validator.check(token, Jiki.secrets.google_oauth_client_id)

      raise InvalidTokenError, "Invalid Google token" unless payload
      raise InvalidTokenError, "Token expired" if Time.zone.at(payload['exp']) < Time.zone.now

      payload
    rescue GoogleIDToken::ValidationError => e
      raise InvalidTokenError, "Google token validation failed: #{e.message}"
    end

    class InvalidTokenError < StandardError; end
  end
end
