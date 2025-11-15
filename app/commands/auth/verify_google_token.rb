module Auth
  class VerifyGoogleToken
    include Mandate

    initialize_with :token

    def call
      {
        'sub' => user_info['id'],
        'email' => user_info['email'],
        'name' => user_info['name'],
        'email_verified' => user_info['verified_email']
      }
    rescue StandardError => e
      raise InvalidGoogleTokenError, "Google token validation failed: #{e.message}"
    end

    private
    memoize
    def access_token
      response = HTTParty.post(
        'https://oauth2.googleapis.com/token',
        body: {
          code: token,
          client_id: google_oauth_client_id,
          client_secret: google_oauth_client_secret,
          grant_type: 'authorization_code',
          redirect_uri: 'postmessage' # Special value for Google's JavaScript client
        }
      )

      raise InvalidGoogleTokenError, "Token exchange failed: #{response.code}: #{response.body}" unless response.success?

      response.parsed_response['access_token']
    end

    memoize
    def user_info
      response = HTTParty.get(
        'https://www.googleapis.com/oauth2/v2/userinfo',
        headers: { 'Authorization' => "Bearer #{access_token}" }
      )

      raise InvalidGoogleTokenError, "UserInfo API returned #{response.code}: #{response.body}" unless response.success?

      response.parsed_response
    end

    memoize
    def google_oauth_client_id = Jiki.secrets.google_oauth_client_id

    memoize
    def google_oauth_client_secret = Jiki.secrets.google_oauth_client_secret
  end
end
