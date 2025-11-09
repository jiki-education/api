require "test_helper"

class User::Jwt::RevokeTokenTest < ActiveSupport::TestCase
  test "revokes JWT and its associated refresh token" do
    user = create(:user)

    # Create a JWT token with an associated refresh token
    refresh_token = user.refresh_tokens.create!(
      aud: "Test Device",
      expires_at: 30.days.from_now
    )

    jwt_token = user.jwt_tokens.create!(
      jti: SecureRandom.uuid,
      aud: "Test Device",
      refresh_token: refresh_token,
      expires_at: 1.hour.from_now
    )

    # Verify both exist
    assert User::JwtToken.exists?(jwt_token.id)
    assert User::RefreshToken.exists?(refresh_token.id)

    # Revoke the token
    User::Jwt::RevokeToken.(user, jwt_token.jti)

    # Both should be deleted
    refute User::JwtToken.exists?(jwt_token.id)
    refute User::RefreshToken.exists?(refresh_token.id)
  end

  test "revokes JWT without refresh token" do
    user = create(:user)

    # Create a JWT token without a refresh token
    jwt_token = user.jwt_tokens.create!(
      jti: SecureRandom.uuid,
      aud: "Test Device",
      expires_at: 1.hour.from_now
    )

    # Verify it exists
    assert User::JwtToken.exists?(jwt_token.id)

    # Revoke the token
    User::Jwt::RevokeToken.(user, jwt_token.jti)

    # JWT should be deleted
    refute User::JwtToken.exists?(jwt_token.id)
  end

  test "does nothing if JWT not found" do
    user = create(:user)

    # Try to revoke a non-existent token
    assert_nothing_raised do
      User::Jwt::RevokeToken.(user, "non-existent-jti")
    end
  end

  test "only revokes JWT for the specified user" do
    user1 = create(:user)
    user2 = create(:user)

    # Create JWTs for both users with different jtis
    jwt1 = user1.jwt_tokens.create!(
      jti: SecureRandom.uuid,
      aud: "Device 1",
      expires_at: 1.hour.from_now
    )

    jwt2 = user2.jwt_tokens.create!(
      jti: SecureRandom.uuid,
      aud: "Device 2",
      expires_at: 1.hour.from_now
    )

    # Revoke only user1's token
    User::Jwt::RevokeToken.(user1, jwt1.jti)

    # Only user1's JWT should be deleted
    refute User::JwtToken.exists?(jwt1.id)
    assert User::JwtToken.exists?(jwt2.id)
  end
end
