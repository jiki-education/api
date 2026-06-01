require "test_helper"

class Auth::VerifyExercismTokenTest < ActiveSupport::TestCase
  test "returns payload for valid authorization code" do
    code = "valid-exercism-auth-code"
    code_verifier = "valid-code-verifier"
    access_token = "access-token-123"
    exercism_user_info = {
      'id' => 1530,
      'handle' => 'iHiD',
      'name' => 'Jeremy Walker',
      'email' => 'ihid@exercism.org',
      'avatar_url' => 'https://exercism.org/avatars/1530/0',
      'membership_status' => 'lifetime_insider'
    }

    stub_token_exchange_success(code, code_verifier, access_token)
    stub_userinfo_success(access_token, exercism_user_info)

    result = Auth::VerifyExercismToken.(code, code_verifier)

    assert_equal '1530', result['id']
    assert_equal 'ihid@exercism.org', result['email']
    assert_equal 'Jeremy Walker', result['name']
    assert_equal 'iHiD', result['handle']
    assert_equal 'https://exercism.org/avatars/1530/0', result['avatar_url']
  end

  test "raises InvalidExercismTokenError for invalid authorization code" do
    code = "invalid-code"
    code_verifier = "code-verifier"

    stub_token_exchange_failure(code, code_verifier, 400, { 'error' => 'invalid_grant' })

    assert_raises(InvalidExercismTokenError) do
      Auth::VerifyExercismToken.(code, code_verifier)
    end
  end

  test "raises InvalidExercismTokenError when token exchange fails" do
    code = "expired-code"
    code_verifier = "code-verifier"

    stub_token_exchange_failure(code, code_verifier, 400, { 'error' => 'authorization code expired' })

    error = assert_raises(InvalidExercismTokenError) do
      Auth::VerifyExercismToken.(code, code_verifier)
    end

    assert_match(/Token exchange failed/, error.message)
  end

  test "raises InvalidExercismTokenError when userinfo API fails" do
    code = "valid-code"
    code_verifier = "code-verifier"
    access_token = "access-token-123"

    stub_token_exchange_success(code, code_verifier, access_token)
    stub_userinfo_failure(access_token, 401, { 'error' => 'invalid_token' })

    error = assert_raises(InvalidExercismTokenError) do
      Auth::VerifyExercismToken.(code, code_verifier)
    end

    assert_match(/UserInfo API returned 401/, error.message)
  end

  test "raises InvalidExercismTokenError when network error occurs" do
    code = "valid-code"
    code_verifier = "code-verifier"

    stub_request(:post, "#{Jiki.config.exercism_base_url}/oauth/token").
      to_raise(StandardError.new("Network error"))

    error = assert_raises(InvalidExercismTokenError) do
      Auth::VerifyExercismToken.(code, code_verifier)
    end

    assert_match(/Exercism token validation failed/, error.message)
    assert_match(/Network error/, error.message)
  end

  private
  def redirect_uri = "#{Jiki.config.frontend_base_url}/auth/exercism/callback"

  def stub_token_exchange_success(code, code_verifier, access_token)
    stub_request(:post, "#{Jiki.config.exercism_base_url}/oauth/token").
      with(
        body: {
          'grant_type' => 'authorization_code',
          'code' => code,
          'code_verifier' => code_verifier,
          'client_id' => Jiki.secrets.exercism_oauth_client_id,
          'client_secret' => Jiki.secrets.exercism_oauth_client_secret,
          'redirect_uri' => redirect_uri
        }
      ).
      to_return(
        status: 200,
        body: { 'access_token' => access_token, 'token_type' => 'Bearer' }.to_json,
        headers: { 'Content-Type' => 'application/json' }
      )
  end

  def stub_token_exchange_failure(code, code_verifier, status_code, response_body)
    stub_request(:post, "#{Jiki.config.exercism_base_url}/oauth/token").
      with(
        body: {
          'grant_type' => 'authorization_code',
          'code' => code,
          'code_verifier' => code_verifier,
          'client_id' => Jiki.secrets.exercism_oauth_client_id,
          'client_secret' => Jiki.secrets.exercism_oauth_client_secret,
          'redirect_uri' => redirect_uri
        }
      ).
      to_return(
        status: status_code,
        body: response_body.to_json,
        headers: { 'Content-Type' => 'application/json' }
      )
  end

  def stub_userinfo_success(access_token, response_body)
    stub_request(:get, "#{Jiki.config.exercism_base_url}/api/oauth/userinfo").
      with(headers: { 'Authorization' => "Bearer #{access_token}" }).
      to_return(
        status: 200,
        body: response_body.to_json,
        headers: { 'Content-Type' => 'application/json' }
      )
  end

  def stub_userinfo_failure(access_token, status_code, response_body)
    stub_request(:get, "#{Jiki.config.exercism_base_url}/api/oauth/userinfo").
      with(headers: { 'Authorization' => "Bearer #{access_token}" }).
      to_return(
        status: status_code,
        body: response_body.to_json,
        headers: { 'Content-Type' => 'application/json' }
      )
  end
end
