require "test_helper"

class Auth::RefreshTokensControllerTest < ApplicationControllerTest
  setup do
    @user = create(:user, email: "test@example.com", password: "password123")
  end

  test "POST refresh with valid token returns new access token" do
    # Create a valid refresh token
    refresh_token = @user.refresh_tokens.create!(
      aud: "Test Device",
      expires_at: 30.days.from_now
    )

    post refresh_path, params: {
      refresh_token: refresh_token.token
    }, as: :json

    assert_response :ok

    json = response.parsed_body
    assert_equal "Access token refreshed successfully", json["message"]

    # Check new JWT access token in response header
    token = response.headers["Authorization"]
    assert token.present?
    assert token.start_with?("Bearer ")
  end

  test "POST refresh with invalid token returns 401" do
    post refresh_path, params: {
      refresh_token: "invalid_token_that_does_not_exist"
    }, as: :json

    assert_response :unauthorized

    json = response.parsed_body
    assert_equal "invalid_token", json["error"]["type"]
    assert_equal "Invalid refresh token", json["error"]["message"]

    # No JWT token should be present
    assert_nil response.headers["Authorization"]
  end

  test "POST refresh with expired token returns 401 and destroys token" do
    # Create an expired refresh token
    refresh_token = @user.refresh_tokens.create!(
      aud: "Test Device",
      expires_at: 1.day.ago
    )

    token_id = refresh_token.id

    post refresh_path, params: {
      refresh_token: refresh_token.token
    }, as: :json

    assert_response :unauthorized

    json = response.parsed_body
    assert_equal "expired_token", json["error"]["type"]
    assert_equal "Refresh token has expired", json["error"]["message"]

    # Expired token should be destroyed
    refute User::RefreshToken.exists?(token_id)

    # No JWT token should be present
    assert_nil response.headers["Authorization"]
  end

  test "POST refresh without token parameter returns 400" do
    post refresh_path, params: {}, as: :json

    assert_response :bad_request

    json = response.parsed_body
    assert_equal "invalid_request", json["error"]["type"]
    assert_equal "Refresh token is required", json["error"]["message"]

    # No JWT token should be present
    assert_nil response.headers["Authorization"]
  end

  test "POST refresh with blank token returns 400" do
    post refresh_path, params: {
      refresh_token: ""
    }, as: :json

    assert_response :bad_request

    json = response.parsed_body
    assert_equal "invalid_request", json["error"]["type"]
    assert_equal "Refresh token is required", json["error"]["message"]
  end

  test "POST refresh creates new JWT token in allowlist" do
    refresh_token = @user.refresh_tokens.create!(
      aud: "Test Device",
      expires_at: 30.days.from_now
    )

    initial_jwt_count = @user.jwt_tokens.count

    post refresh_path, params: {
      refresh_token: refresh_token.token
    }, as: :json

    assert_response :ok

    # A new JWT token should be added to allowlist
    @user.reload
    assert_equal initial_jwt_count + 1, @user.jwt_tokens.count
  end

  test "POST refresh can be called multiple times with same refresh token" do
    refresh_token = @user.refresh_tokens.create!(
      aud: "Test Device",
      expires_at: 30.days.from_now
    )

    # First refresh
    post refresh_path, params: {
      refresh_token: refresh_token.token
    }, as: :json

    assert_response :ok
    first_access_token = response.headers["Authorization"]

    # Second refresh with same refresh token
    post refresh_path, params: {
      refresh_token: refresh_token.token
    }, as: :json

    assert_response :ok
    second_access_token = response.headers["Authorization"]

    # Both should succeed and return different access tokens
    assert first_access_token.present?
    assert second_access_token.present?
    refute_equal first_access_token, second_access_token
  end

  test "POST refresh does not work after user logout" do
    # Login to get refresh token
    post user_session_path, params: {
      user: {
        email: "test@example.com",
        password: "password123"
      }
    }, as: :json

    json = response.parsed_body
    refresh_token_value = json["refresh_token"]
    access_token = response.headers["Authorization"]

    assert refresh_token_value.present?
    assert access_token.present?

    # Logout (revokes all refresh tokens)
    delete destroy_user_session_path,
      headers: { "Authorization" => access_token },
      as: :json

    assert_response :no_content

    # Try to refresh with the now-revoked token
    post refresh_path, params: {
      refresh_token: refresh_token_value
    }, as: :json

    assert_response :unauthorized

    json = response.parsed_body
    assert_equal "invalid_token", json["error"]["type"]
  end

  private
  def refresh_path
    "/auth/refresh"
  end
end
