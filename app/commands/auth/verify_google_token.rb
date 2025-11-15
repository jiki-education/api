module Auth
  class VerifyGoogleToken
    include Mandate

    initialize_with :token

    def call
      access_token = exchange_code_for_token
      user_info = fetch_user_info(access_token)
      parse_user_info(user_info)
    rescue StandardError => e
      raise InvalidGoogleTokenError, "Google token validation failed: #{e.message}"
    end

    private
    def exchange_code_for_token
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

    def fetch_user_info(access_token)
      response = HTTParty.get(
        'https://www.googleapis.com/oauth2/v2/userinfo',
        headers: { 'Authorization' => "Bearer #{access_token}" }
      )

      raise InvalidGoogleTokenError, "UserInfo API returned #{response.code}: #{response.body}" unless response.success?

      response.parsed_response
    end

    def parse_user_info(response)
      {
        'sub' => response['id'],
        'email' => response['email'],
        'name' => response['name'],
        'email_verified' => response['verified_email']
      }
    end

    memoize
    def google_oauth_client_id = Jiki.secrets.google_oauth_client_id

    memoize
    def google_oauth_client_secret = Jiki.secrets.google_oauth_client_secret
  end
end
