module Auth
  class VerifyGoogleToken
    include Mandate

    initialize_with :token

    def call
      Google::Auth::IDTokens.verify_oidc(token, aud: google_oauth_client_id)
    rescue Google::Auth::IDTokens::VerificationError => e
      raise InvalidGoogleTokenError, "Google token validation failed: #{e.message}"
    end

    private
    memoize
    def google_oauth_client_id = Jiki.secrets.google_oauth_client_id
  end
end
