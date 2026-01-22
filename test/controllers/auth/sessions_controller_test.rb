require "test_helper"

class Auth::SessionsControllerTest < ApplicationControllerTest
  setup do
    @user = create(:user, email: "test@example.com", password: "password123")
  end

  test "POST login returns user data with valid credentials" do
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

  test "DELETE logout clears session" do
    # Login first
    post user_session_path, params: {
      user: {
        email: "test@example.com",
        password: "password123"
      }
    }, as: :json

    assert_response :ok

    # Now logout
    delete destroy_user_session_path, as: :json

    assert_response :no_content

    # Verify we're no longer authenticated
    get internal_me_path, as: :json
    assert_response :unauthorized
  end

  test "DELETE logout without session returns success" do
    # Logout without being logged in should still succeed
    delete destroy_user_session_path, as: :json

    assert_response :no_content
  end
end
