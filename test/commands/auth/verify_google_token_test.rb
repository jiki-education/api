require "test_helper"

class Auth::VerifyGoogleTokenTest < ActiveSupport::TestCase
  test "returns payload for valid token" do
    token = "valid-google-token"
    expected_payload = {
      'sub' => 'google-user-123',
      'email' => 'user@gmail.com',
      'name' => 'Test User',
      'exp' => 1.hour.from_now.to_i
    }

    validator = mock
    validator.expects(:check).with(token, Jiki.secrets.google_oauth_client_id).returns(expected_payload)
    GoogleIDToken::Validator.expects(:new).returns(validator)

    result = Auth::VerifyGoogleToken.(token)

    assert_equal expected_payload, result
  end

  test "raises InvalidTokenError for invalid token" do
    token = "invalid-token"

    validator = mock
    validator.expects(:check).with(token, Jiki.secrets.google_oauth_client_id).returns(nil)
    GoogleIDToken::Validator.expects(:new).returns(validator)

    assert_raises(Auth::VerifyGoogleToken::InvalidTokenError) do
      Auth::VerifyGoogleToken.(token)
    end
  end

  test "raises InvalidTokenError for expired token" do
    token = "expired-token"
    expired_payload = {
      'sub' => 'google-user-123',
      'email' => 'user@gmail.com',
      'exp' => 1.hour.ago.to_i
    }

    validator = mock
    validator.expects(:check).with(token, Jiki.secrets.google_oauth_client_id).returns(expired_payload)
    GoogleIDToken::Validator.expects(:new).returns(validator)

    error = assert_raises(Auth::VerifyGoogleToken::InvalidTokenError) do
      Auth::VerifyGoogleToken.(token)
    end

    assert_match(/Token expired/, error.message)
  end

  test "raises InvalidTokenError when validation fails" do
    token = "malformed-token"

    validator = mock
    validator.expects(:check).with(token, Jiki.secrets.google_oauth_client_id).
      raises(GoogleIDToken::ValidationError.new("Signature verification failed"))
    GoogleIDToken::Validator.expects(:new).returns(validator)

    error = assert_raises(Auth::VerifyGoogleToken::InvalidTokenError) do
      Auth::VerifyGoogleToken.(token)
    end

    assert_match(/Google token validation failed/, error.message)
    assert_match(/Signature verification failed/, error.message)
  end
end
