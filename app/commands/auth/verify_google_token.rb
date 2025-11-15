module Auth
  class VerifyGoogleToken
    include Mandate

    initialize_with :token

    def call
      Rails.logger.info "[GoogleOAuth] Starting token verification"
      Rails.logger.debug "[GoogleOAuth] Authorization code: #{token[0..10]}..." # Log first few chars only

      access_token = exchange_code_for_token
      user_info = fetch_user_info(access_token)
      result = parse_user_info(user_info)

      Rails.logger.info "[GoogleOAuth] Successfully verified user: #{result['email']}"
      result
    rescue StandardError => e
      Rails.logger.error "[GoogleOAuth] Verification failed: #{e.class} - #{e.message}"
      raise InvalidGoogleTokenError, "Google token validation failed: #{e.message}"
    end

    private
    def exchange_code_for_token
      Rails.logger.info "[GoogleOAuth] Exchanging authorization code for access token"

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

      Rails.logger.debug "[GoogleOAuth] Token exchange response code: #{response.code}"

      unless response.success?
        Rails.logger.error "[GoogleOAuth] Token exchange failed: #{response.code}: #{response.body}"
        raise InvalidGoogleTokenError, "Token exchange failed: #{response.code}: #{response.body}"
      end

      access_token = response.parsed_response['access_token']
      Rails.logger.info "[GoogleOAuth] Successfully obtained access token"
      Rails.logger.debug "[GoogleOAuth] Access token: #{access_token[0..10]}..." if access_token

      access_token
    end

    def fetch_user_info(access_token)
      Rails.logger.info "[GoogleOAuth] Fetching user info from Google"

      response = HTTParty.get(
        'https://www.googleapis.com/oauth2/v2/userinfo',
        headers: { 'Authorization' => "Bearer #{access_token}" }
      )

      Rails.logger.debug "[GoogleOAuth] UserInfo response code: #{response.code}"

      unless response.success?
        Rails.logger.error "[GoogleOAuth] UserInfo API failed: #{response.code}: #{response.body}"
        raise InvalidGoogleTokenError, "UserInfo API returned #{response.code}: #{response.body}"
      end

      Rails.logger.info "[GoogleOAuth] Successfully fetched user info"
      response.parsed_response
    end

    def parse_user_info(response)
      Rails.logger.debug "[GoogleOAuth] Parsing user info: id=#{response['id']}, email=#{response['email']}"

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
