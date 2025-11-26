require "test_helper"

class Auth::VerifyGoogleTokenTest < ActiveSupport::TestCase
  test "returns payload for valid authorization code" do
    code = "valid-google-auth-code"
    access_token = "access-token-123"
    google_user_info = {
      'id' => 'google-user-123',
      'email' => 'user@gmail.com',
      'name' => 'Test User',
      'verified_email' => true
    }

    stub_token_exchange_success(code, access_token)
    stub_userinfo_success(access_token, google_user_info)

    result = Auth::VerifyGoogleToken.(code)

    assert_equal 'google-user-123', result['sub']
    assert_equal 'user@gmail.com', result['email']
    assert_equal 'Test User', result['name']
    assert result['email_verified']
  end

  test "raises InvalidGoogleTokenError for invalid authorization code" do
    code = "invalid-code"

    stub_token_exchange_failure(code, 400, { 'error' => 'invalid_grant' })

    assert_raises(InvalidGoogleTokenError) do
      Auth::VerifyGoogleToken.(code)
    end
  end

  test "raises InvalidGoogleTokenError when token exchange fails" do
    code = "expired-code"

    stub_token_exchange_failure(code, 400, { 'error' => 'authorization code expired' })

    error = assert_raises(InvalidGoogleTokenError) do
      Auth::VerifyGoogleToken.(code)
    end

    assert_match(/Token exchange failed/, error.message)
  end

  test "raises InvalidGoogleTokenError when userinfo API fails" do
    code = "valid-code"
    access_token = "access-token-123"

    stub_token_exchange_success(code, access_token)
    stub_userinfo_failure(access_token, 401, { 'error' => 'invalid_token' })

    error = assert_raises(InvalidGoogleTokenError) do
      Auth::VerifyGoogleToken.(code)
    end

    assert_match(/UserInfo API returned 401/, error.message)
  end

  test "raises InvalidGoogleTokenError when network error occurs" do
    code = "valid-code"

    stub_request(:post, "https://oauth2.googleapis.com/token").
      to_raise(StandardError.new("Network error"))

    error = assert_raises(InvalidGoogleTokenError) do
      Auth::VerifyGoogleToken.(code)
    end

    assert_match(/Google token validation failed/, error.message)
    assert_match(/Network error/, error.message)
  end

  private
  def stub_token_exchange_success(code, access_token)
    stub_request(:post, "https://oauth2.googleapis.com/token").
      with(
        body: {
          'code' => code,
          'client_id' => Jiki.secrets.google_oauth_client_id,
          'client_secret' => Jiki.secrets.google_oauth_client_secret,
          'grant_type' => 'authorization_code',
          'redirect_uri' => 'postmessage'
        }
      ).
      to_return(
        status: 200,
        body: { 'access_token' => access_token, 'token_type' => 'Bearer' }.to_json,
        headers: { 'Content-Type' => 'application/json' }
      )
  end

  def stub_token_exchange_failure(code, status_code, response_body)
    stub_request(:post, "https://oauth2.googleapis.com/token").
      with(
        body: {
          'code' => code,
          'client_id' => Jiki.secrets.google_oauth_client_id,
          'client_secret' => Jiki.secrets.google_oauth_client_secret,
          'grant_type' => 'authorization_code',
          'redirect_uri' => 'postmessage'
        }
      ).
      to_return(
        status: status_code,
        body: response_body.to_json,
        headers: { 'Content-Type' => 'application/json' }
      )
  end

  def stub_userinfo_success(access_token, response_body)
    stub_request(:get, "https://www.googleapis.com/oauth2/v2/userinfo").
      with(headers: { 'Authorization' => "Bearer #{access_token}" }).
      to_return(
        status: 200,
        body: response_body.to_json,
        headers: { 'Content-Type' => 'application/json' }
      )
  end

  def stub_userinfo_failure(access_token, status_code, response_body)
    stub_request(:get, "https://www.googleapis.com/oauth2/v2/userinfo").
      with(headers: { 'Authorization' => "Bearer #{access_token}" }).
      to_return(
        status: status_code,
        body: response_body.to_json,
        headers: { 'Content-Type' => 'application/json' }
      )
  end
end
