require "test_helper"

class Auth::SessionsControllerTest < ApplicationControllerTest
  setup do
    @user = create(:user, email: "test@example.com", password: "password123")
  end

  test "POST login returns JWT token with valid credentials" do
    post user_session_path, params: {
      user: {
        email: "test@example.com",
        password: "password123"
      }
    }, as: :json

    assert_response :ok

    json = response.parsed_body
    assert_equal @user.handle, json["user"]["handle"]
    assert_equal "test@example.com", json["user"]["email"]
    assert_equal @user.name, json["user"]["name"]
    assert_equal "standard", json["user"]["membership_type"]

    # Check JWT token in response header
    token = response.headers["Authorization"]
    assert token.present?
    assert token.start_with?("Bearer ")
  end

  test "POST login returns error with invalid password" do
    post user_session_path, params: {
      user: {
        email: "test@example.com",
        password: "wrongpassword"
      }
    }, as: :json

    assert_response :unauthorized

    json = response.parsed_body
    assert_equal "unauthorized", json["error"]["type"]
    assert json["error"]["message"].present?

    # No JWT token should be present
    assert_nil response.headers["Authorization"]
  end

  test "POST login returns error with non-existent email" do
    post user_session_path, params: {
      user: {
        email: "nonexistent@example.com",
        password: "password123"
      }
    }, as: :json

    assert_response :unauthorized

    json = response.parsed_body
    assert_equal "unauthorized", json["error"]["type"]
    assert json["error"]["message"].present?
  end

  test "DELETE logout revokes the JWT token" do
    # First, sign in to get a token
    post user_session_path, params: {
      user: {
        email: "test@example.com",
        password: "password123"
      }
    }, as: :json

    token = response.headers["Authorization"]
    assert token.present?

    # Now logout with the token
    delete destroy_user_session_path,
      headers: { "Authorization" => token },
      as: :json

    assert_response :no_content

    # All refresh tokens should be revoked on logout
    @user.reload
    assert_equal 0, @user.refresh_tokens.count
  end

  test "DELETE logout without token returns error" do
    delete destroy_user_session_path, as: :json

    assert_response :unauthorized

    json = response.parsed_body
    assert_equal "unauthorized", json["error"]["type"]
  end

  test "POST login includes membershipType in JWT payload" do
    post user_session_path, params: {
      user: {
        email: "test@example.com",
        password: "password123"
      }
    }, as: :json

    assert_response :ok

    # Extract and decode the JWT token
    token = response.headers["Authorization"].sub("Bearer ", "")
    p Jiki.secrets.devise_jwt_secret_key
    payload, _header = JWT.decode(token, Jiki.secrets.jwt_secret, true, { verify_expiration: false, algorithm: 'HS256' })

    # Verify membershipType is included in the JWT payload
    assert_equal "standard", payload["membershipType"]
    assert payload["sub"].present? # User ID
    assert payload["scp"].present? # Scope
    assert payload["jti"].present? # JWT ID
  end
end
