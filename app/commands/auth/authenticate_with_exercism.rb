module Auth
  class AuthenticateWithExercism
    include Mandate

    initialize_with :code, :code_verifier

    def call
      Auth::AuthenticateWithOauth.(:exercism, payload)
    end

    private
    memoize
    def payload = Auth::VerifyExercismToken.(code, code_verifier)
  end
end
