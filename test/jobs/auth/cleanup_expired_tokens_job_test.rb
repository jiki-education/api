require "test_helper"

class Auth::CleanupExpiredTokensJobTest < ActiveJob::TestCase
  setup do
    @user = create(:user)
  end

  test "deletes JWT tokens expired more than 1 hour ago" do
    # Create tokens with various expiration times
    old_token = @user.jwt_tokens.create!(
      jti: SecureRandom.uuid,
      aud: "Device 1",
      expires_at: 2.hours.ago # Older than 1 hour buffer
    )

    recent_token = @user.jwt_tokens.create!(
      jti: SecureRandom.uuid,
      aud: "Device 2",
      expires_at: 30.minutes.ago # Within 1 hour buffer
    )

    valid_token = @user.jwt_tokens.create!(
      jti: SecureRandom.uuid,
      aud: "Device 3",
      expires_at: 30.minutes.from_now # Still valid
    )

    Auth::CleanupExpiredTokensJob.perform_now

    # Old token should be deleted
    refute User::JwtToken.exists?(old_token.id)

    # Recent and valid tokens should remain
    assert User::JwtToken.exists?(recent_token.id)
    assert User::JwtToken.exists?(valid_token.id)
  end

  test "deletes refresh tokens expired more than 1 hour ago" do
    # Create tokens with various expiration times
    old_token = @user.refresh_tokens.create!(
      aud: "Device 1",
      expires_at: 2.hours.ago # Older than 1 hour buffer
    )

    recent_token = @user.refresh_tokens.create!(
      aud: "Device 2",
      expires_at: 30.minutes.ago # Within 1 hour buffer
    )

    valid_token = @user.refresh_tokens.create!(
      aud: "Device 3",
      expires_at: 30.days.from_now # Still valid
    )

    Auth::CleanupExpiredTokensJob.perform_now

    # Old token should be deleted
    refute User::RefreshToken.exists?(old_token.id)

    # Recent and valid tokens should remain
    assert User::RefreshToken.exists?(recent_token.id)
    assert User::RefreshToken.exists?(valid_token.id)
  end

  test "deletes both JWT and refresh tokens in a single run" do
    # Create old tokens of both types
    old_jwt = @user.jwt_tokens.create!(
      jti: SecureRandom.uuid,
      aud: "Device 1",
      expires_at: 3.hours.ago
    )

    old_refresh = @user.refresh_tokens.create!(
      aud: "Device 1",
      expires_at: 3.hours.ago
    )

    Auth::CleanupExpiredTokensJob.perform_now

    # Both should be deleted
    refute User::JwtToken.exists?(old_jwt.id)
    refute User::RefreshToken.exists?(old_refresh.id)
  end

  test "handles empty tables gracefully" do
    # Ensure no tokens exist
    User::JwtToken.destroy_all
    User::RefreshToken.destroy_all

    # Should not raise an error
    assert_nothing_raised do
      Auth::CleanupExpiredTokensJob.perform_now
    end
  end

  test "cleanup respects 1-hour buffer" do
    # Create token that expired 59 minutes ago
    # Should NOT be deleted (within the 1-hour buffer)
    token_within_buffer = @user.jwt_tokens.create!(
      jti: SecureRandom.uuid,
      aud: "Device",
      expires_at: 59.minutes.ago
    )

    # Create token that expired 61 minutes ago
    # Should be deleted (past the 1-hour buffer)
    token_past_buffer = @user.jwt_tokens.create!(
      jti: SecureRandom.uuid,
      aud: "Device",
      expires_at: 61.minutes.ago
    )

    Auth::CleanupExpiredTokensJob.perform_now

    # Token within buffer should remain
    assert User::JwtToken.exists?(token_within_buffer.id)

    # Token past buffer should be deleted
    refute User::JwtToken.exists?(token_past_buffer.id)
  end

  test "cleanup works across multiple users" do
    user2 = create(:user)

    # Create old tokens for both users
    @user.jwt_tokens.create!(
      jti: SecureRandom.uuid,
      aud: "Device",
      expires_at: 2.hours.ago
    )

    user2.jwt_tokens.create!(
      jti: SecureRandom.uuid,
      aud: "Device",
      expires_at: 2.hours.ago
    )

    # Create valid tokens for both users
    valid1 = @user.jwt_tokens.create!(
      jti: SecureRandom.uuid,
      aud: "Device",
      expires_at: 30.minutes.from_now
    )

    valid2 = user2.jwt_tokens.create!(
      jti: SecureRandom.uuid,
      aud: "Device",
      expires_at: 30.minutes.from_now
    )

    Auth::CleanupExpiredTokensJob.perform_now

    # Only valid tokens should remain
    assert_equal 2, User::JwtToken.count
    assert User::JwtToken.exists?(valid1.id)
    assert User::JwtToken.exists?(valid2.id)
  end

  test "job can be enqueued via perform_later" do
    assert_enqueued_jobs 0

    Auth::CleanupExpiredTokensJob.perform_later

    assert_enqueued_jobs 1
    assert_enqueued_with job: Auth::CleanupExpiredTokensJob
  end
end
