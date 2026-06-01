module Auth
  class AuthenticateWithGoogle
    include Mandate

    initialize_with :google_token

    def call
      Auth::AuthenticateWithOauth.(:google, payload)
    end

    private
    memoize
    def payload = Auth::VerifyGoogleToken.(google_token)
  end
end
