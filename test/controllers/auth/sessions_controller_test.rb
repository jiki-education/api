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

  test "DELETE logout revokes tokens for current device only" do
    # Simulate two devices logging in
    # Device 1: Desktop (Chrome)
    post user_session_path,
      params: {
        user: {
          email: "test@example.com",
          password: "password123"
        }
      },
      headers: { "User-Agent" => "Desktop Chrome" },
      as: :json

    device1_token = response.headers["Authorization"]
    assert device1_token.present?

    # Device 2: Mobile (Safari)
    post user_session_path,
      params: {
        user: {
          email: "test@example.com",
          password: "password123"
        }
      },
      headers: { "User-Agent" => "Mobile Safari" },
      as: :json

    device2_token = response.headers["Authorization"]
    assert device2_token.present?

    @user.reload
    assert_equal 2, @user.refresh_tokens.count
    assert_equal 2, @user.jwt_tokens.count

    # Logout from Device 1 only
    delete destroy_user_session_path,
      headers: {
        "Authorization" => device1_token,
        "User-Agent" => "Desktop Chrome"
      },
      as: :json

    assert_response :no_content

    @user.reload
    # Device 1 tokens should be gone
    assert_equal 1, @user.refresh_tokens.count
    assert_equal 1, @user.jwt_tokens.count

    # Device 2 access token should still work
    get internal_me_path,
      headers: { "Authorization" => device2_token },
      as: :json

    assert_response :ok

    # Device 1 access token should NOT work
    get internal_me_path,
      headers: { "Authorization" => device1_token },
      as: :json

    assert_response :unauthorized
  end

  test "DELETE logout without token returns error" do
    delete destroy_user_session_path, as: :json

    assert_response :unauthorized

    json = response.parsed_body
    assert_equal "unauthorized", json["error"]["type"]
  end

  test "POST login includes membership_type in JWT payload" do
    post user_session_path, params: {
      user: {
        email: "test@example.com",
        password: "password123"
      }
    }, as: :json

    assert_response :ok

    # Extract and decode the JWT token
    token = response.headers["Authorization"].sub("Bearer ", "")
    payload, _header = JWT.decode(token, Jiki.secrets.jwt_secret, true, { verify_expiration: false, algorithm: 'HS256' })

    # Verify membership_type is included in the JWT payload
    assert_equal "standard", payload["membership_type"]
    assert payload["sub"].present? # User ID
    assert payload["scp"].present? # Scope
    assert payload["jti"].present? # JWT ID
  end
end
