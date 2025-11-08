require "test_helper"

class User::Jwt::ExtractPayloadTest < ActiveSupport::TestCase
  test "extracts payload from token string" do
    user = create(:user)

    # Generate a real JWT token
    secret = Jiki.secrets.jwt_secret
    exp = 1.hour.from_now.to_i
    payload = { sub: user.id.to_s, scp: "user", exp: exp, jti: SecureRandom.uuid }
    token = JWT.encode(payload, secret, "HS256")

    # Test extraction from raw token string
    extracted = User::Jwt::ExtractPayload.(token)

    refute_nil extracted
    assert_equal user.id.to_s, extracted["sub"]
    assert_equal "user", extracted["scp"]
    assert_equal exp, extracted["exp"]
  end

  test "returns nil for invalid token" do
    result = User::Jwt::ExtractPayload.("invalid-token")
    assert_nil result
  end

  test "returns nil for nil token" do
    result = User::Jwt::ExtractPayload.(nil)
    assert_nil result
  end

  test "returns nil for empty string" do
    result = User::Jwt::ExtractPayload.("")
    assert_nil result
  end

  test "extracts payload with custom claims" do
    user = create(:user)

    # Generate a JWT with custom claims
    secret = Jiki.secrets.jwt_secret
    exp = 1.hour.from_now.to_i
    jti = SecureRandom.uuid
    payload = {
      sub: user.id.to_s,
      scp: "user",
      exp: exp,
      jti: jti,
      membershipType: "premium",
      aud: "Custom Browser"
    }
    token = JWT.encode(payload, secret, "HS256")

    extracted = User::Jwt::ExtractPayload.(token)

    assert_equal "premium", extracted["membershipType"]
    assert_equal "Custom Browser", extracted["aud"]
    assert_equal jti, extracted["jti"]
  end
end
