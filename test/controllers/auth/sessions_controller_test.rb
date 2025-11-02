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

    # The user's JTI should be updated, invalidating the old token
    @user.reload
    assert @user.jti.present?
  end

  test "DELETE logout without token returns error" do
    delete destroy_user_session_path, as: :json

    assert_response :unauthorized

    json = response.parsed_body
    assert_equal "unauthorized", json["error"]["type"]
  end
end
