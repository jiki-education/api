module Auth
  class VerifyExercismToken
    include Mandate

    initialize_with :code, :code_verifier

    def call
      {
        'id' => user_info['id'].to_s,
        'email' => user_info['email'],
        'name' => user_info['name'],
        'handle' => user_info['handle'],
        'avatar_url' => user_info['avatar_url'],
        'is_insider' => user_info['is_insider'] == true,
        'is_bootcamp_member' => user_info['is_bootcamp_member'] == true
      }
    rescue StandardError => e
      raise InvalidExercismTokenError, "Exercism token validation failed: #{e.message}"
    end

    private
    memoize
    def access_token
      response = HTTParty.post(
        "#{exercism_base_url}/oauth/token",
        body: {
          grant_type: 'authorization_code',
          code:,
          code_verifier:,
          client_id: Jiki.secrets.exercism_oauth_client_id,
          client_secret: Jiki.secrets.exercism_oauth_client_secret,
          redirect_uri:
        }
      )

      raise InvalidExercismTokenError, "Token exchange failed: #{response.code}: #{response.body}" unless response.success?

      response.parsed_response['access_token']
    end

    memoize
    def user_info
      response = HTTParty.get(
        "#{exercism_base_url}/api/oauth/userinfo",
        headers: { 'Authorization' => "Bearer #{access_token}" }
      )

      raise InvalidExercismTokenError, "UserInfo API returned #{response.code}: #{response.body}" unless response.success?

      response.parsed_response
    end

    # Must exactly match the redirect URI registered against Jiki's
    # Doorkeeper application on Exercism, and the one the frontend
    # used in its authorize request.
    def redirect_uri = "#{Jiki.config.frontend_base_url}/auth/exercism/callback"

    memoize
    def exercism_base_url = Jiki.config.exercism_base_url
  end
end
