require "test_helper"

class User::Jwt::CreateRefreshTokenTest < ActiveSupport::TestCase
  test "creates refresh token with User-Agent from Current" do
    user = create(:user)

    Current.user_agent = "Test Browser"

    refresh_token = User::Jwt::CreateRefreshToken.(user)

    refute_nil refresh_token
    assert_equal user.id, refresh_token.user_id
    assert_equal "Test Browser", refresh_token.aud
    assert_in_delta 30.days.from_now, refresh_token.expires_at, 1.second
    assert refresh_token.persisted?
  end

  test "links refresh token to JWT record when Current.jwt_record_id is set" do
    user = create(:user)

    # Create a JWT token
    jwt_token = user.jwt_tokens.create!(
      jti: SecureRandom.uuid,
      aud: "Test Device",
      expires_at: 1.hour.from_now
    )

    Current.jwt_record_id = jwt_token.id
    Current.user_agent = "Test Browser"

    refresh_token = User::Jwt::CreateRefreshToken.(user)

    # JWT should now be linked to the refresh token
    jwt_token.reload
    assert_equal refresh_token.id, jwt_token.refresh_token_id
    assert_equal refresh_token, jwt_token.refresh_token
  end

  test "does not link JWT when Current.jwt_record_id is not set" do
    user = create(:user)

    Current.user_agent = "Test Browser"
    Current.jwt_record_id = nil

    refresh_token = User::Jwt::CreateRefreshToken.(user)

    refute_nil refresh_token
    # Verify no JWTs are linked to this refresh token
    assert_equal 0, user.jwt_tokens.where(refresh_token_id: refresh_token.id).count
  end

  test "does not error if JWT record does not exist" do
    user = create(:user)

    Current.user_agent = "Test Browser"
    Current.jwt_record_id = 99_999 # Non-existent ID

    assert_nothing_raised do
      User::Jwt::CreateRefreshToken.(user)
    end
  end
end
