require "test_helper"

class JwtAuthenticationTest < ApplicationControllerTest
  setup do
    @user = create(:user, email: "test@example.com", password: "password123")
  end

  test "GET protected endpoint with invalid JWT returns 401" do
    # Use a completely invalid JWT token
    get internal_me_path,
      headers: { "Authorization" => "Bearer invalid_jwt_token" },
      as: :json

    assert_response :unauthorized

    json = response.parsed_body
    assert_equal "unauthorized", json["error"]["type"]
  end

  test "GET protected endpoint with expired JWT returns 401" do
    # Create a JWT token that's already expired
    exp = 1.hour.ago.to_i
    payload = {
      sub: @user.id.to_s,
      scp: "user",
      exp: exp,
      jti: SecureRandom.uuid,
      membershipType: "standard"
    }

    token = JWT.encode(payload, Jiki.secrets.jwt_secret, "HS256")

    # Add to allowlist (so it's not rejected for being unlisted)
    @user.jwt_tokens.create!(
      jti: payload[:jti],
      expires_at: Time.zone.at(exp)
    )

    # Try to access protected endpoint with expired token
    get internal_me_path,
      headers: { "Authorization" => "Bearer #{token}" },
      as: :json

    assert_response :unauthorized

    json = response.parsed_body
    assert_equal "unauthorized", json["error"]["type"]
  end

  test "GET protected endpoint with malformed JWT returns 401" do
    # Test various malformed JWT formats
    malformed_tokens = [
      "not_a_jwt_at_all",
      "Bearer.malformed.jwt",
      "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.corrupted",
      "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJzdWIiOiIxMjM0NTY3ODkwIn0.invalid_signature"
    ]

    malformed_tokens.each do |malformed_token|
      get internal_me_path,
        headers: { "Authorization" => "Bearer #{malformed_token}" },
        as: :json

      assert_response :unauthorized, "Expected 401 for malformed token: #{malformed_token}"

      json = response.parsed_body
      assert_equal "unauthorized", json["error"]["type"]
    end
  end

  test "GET protected endpoint with JWT signed with wrong secret returns 401" do
    # Create a JWT signed with a different secret
    wrong_secret = "wrong_secret_key_12345678901234567890"
    payload = {
      sub: @user.id.to_s,
      scp: "user",
      exp: 1.hour.from_now.to_i,
      jti: SecureRandom.uuid
    }

    token = JWT.encode(payload, wrong_secret, "HS256")

    get internal_me_path,
      headers: { "Authorization" => "Bearer #{token}" },
      as: :json

    assert_response :unauthorized

    json = response.parsed_body
    assert_equal "unauthorized", json["error"]["type"]
  end

  test "GET protected endpoint with JWT missing Bearer prefix returns 401" do
    # Create a valid JWT but don't prefix with "Bearer "
    token, payload = Warden::JWTAuth::UserEncoder.new.(@user, :user, nil)

    @user.jwt_tokens.create!(
      jti: payload["jti"],
      aud: payload["aud"],
      expires_at: Time.zone.at(payload["exp"].to_i)
    )

    # Send without "Bearer " prefix
    get internal_me_path,
      headers: { "Authorization" => token }, # Missing "Bearer "
      as: :json

    assert_response :unauthorized

    json = response.parsed_body
    assert_equal "unauthorized", json["error"]["type"]
  end

  test "GET protected endpoint with JWT not in allowlist returns 401" do
    # Create a valid JWT that's properly signed but not in the allowlist
    token, _payload = Warden::JWTAuth::UserEncoder.new.(@user, :user, nil)

    # Intentionally don't add to allowlist

    get internal_me_path,
      headers: { "Authorization" => "Bearer #{token}" },
      as: :json

    assert_response :unauthorized

    json = response.parsed_body
    assert_equal "unauthorized", json["error"]["type"]
  end

  test "GET protected endpoint with revoked JWT returns 401" do
    # Create a valid JWT and add to allowlist
    token, payload = Warden::JWTAuth::UserEncoder.new.(@user, :user, nil)

    jwt_record = @user.jwt_tokens.create!(
      jti: payload["jti"],
      aud: payload["aud"],
      expires_at: Time.zone.at(payload["exp"].to_i)
    )

    # Verify it works first
    get internal_me_path,
      headers: { "Authorization" => "Bearer #{token}" },
      as: :json

    assert_response :ok

    # Revoke the token
    jwt_record.destroy

    # Now it should fail
    get internal_me_path,
      headers: { "Authorization" => "Bearer #{token}" },
      as: :json

    assert_response :unauthorized

    json = response.parsed_body
    assert_equal "unauthorized", json["error"]["type"]
  end
end
