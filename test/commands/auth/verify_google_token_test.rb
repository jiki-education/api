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

    Google::Auth::IDTokens.expects(:verify_oidc).with(
      token,
      aud: Jiki.secrets.google_oauth_client_id
    ).returns(expected_payload)

    result = Auth::VerifyGoogleToken.(token)

    assert_equal expected_payload, result
  end

  test "raises InvalidGoogleTokenError for invalid token" do
    token = "invalid-token"

    Google::Auth::IDTokens.expects(:verify_oidc).with(
      token,
      aud: Jiki.secrets.google_oauth_client_id
    ).raises(Google::Auth::IDTokens::VerificationError.new("Invalid token"))

    assert_raises(InvalidGoogleTokenError) do
      Auth::VerifyGoogleToken.(token)
    end
  end

  test "raises InvalidGoogleTokenError for expired token" do
    token = "expired-token"

    Google::Auth::IDTokens.expects(:verify_oidc).with(
      token,
      aud: Jiki.secrets.google_oauth_client_id
    ).raises(Google::Auth::IDTokens::VerificationError.new("Token expired"))

    error = assert_raises(InvalidGoogleTokenError) do
      Auth::VerifyGoogleToken.(token)
    end

    assert_match(/Token expired/, error.message)
  end

  test "raises InvalidGoogleTokenError when validation fails" do
    token = "malformed-token"

    Google::Auth::IDTokens.expects(:verify_oidc).with(
      token,
      aud: Jiki.secrets.google_oauth_client_id
    ).raises(Google::Auth::IDTokens::VerificationError.new("Signature verification failed"))

    error = assert_raises(InvalidGoogleTokenError) do
      Auth::VerifyGoogleToken.(token)
    end

    assert_match(/Google token validation failed/, error.message)
    assert_match(/Signature verification failed/, error.message)
  end
end
