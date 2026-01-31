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

  test "POST login returns unconfirmed error for unconfirmed user" do
    create(:user, :unconfirmed, email: "unconfirmed@example.com", password: "password123")

    post user_session_path, params: {
      user: {
        email: "unconfirmed@example.com",
        password: "password123"
      }
    }, as: :json

    assert_response :unauthorized

    json = response.parsed_body
    assert_equal "unconfirmed", json["error"]["type"]
    assert_equal "unconfirmed@example.com", json["error"]["email"]
  end

  test "POST login does not create session for unconfirmed user" do
    create(:user, :unconfirmed, email: "unconfirmed@example.com", password: "password123")

    post user_session_path, params: {
      user: {
        email: "unconfirmed@example.com",
        password: "password123"
      }
    }, as: :json

    assert_response :unauthorized

    # Verify no session was created
    get internal_me_path, as: :json
    assert_response :unauthorized
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

  test "DELETE logout without session returns unauthorized" do
    # Devise 5 returns 401 Unauthorized when logging out without a session
    delete destroy_user_session_path, as: :json

    assert_response :unauthorized
  end

  # 2FA Tests
  test "POST login for admin without 2FA setup returns 2fa_setup_required" do
    admin = create(:user, :admin, email: "admin@example.com", password: "password123")

    post user_session_path, params: {
      user: {
        email: "admin@example.com",
        password: "password123"
      }
    }, as: :json

    assert_response :ok

    json = response.parsed_body
    assert_equal "2fa_setup_required", json["status"]
    assert json["provisioning_uri"].present?
    assert json["provisioning_uri"].start_with?("otpauth://totp/Jiki:")

    # Verify admin was NOT signed in
    get internal_me_path, as: :json
    assert_response :unauthorized

    # Verify OTP secret was generated
    admin.reload
    assert admin.otp_secret.present?
  end

  test "POST login for admin with 2FA enabled returns 2fa_required" do
    admin = create(:user, :admin, email: "admin@example.com", password: "password123")
    User::GenerateOtpSecret.(admin)
    User::EnableOtp.(admin)

    post user_session_path, params: {
      user: {
        email: "admin@example.com",
        password: "password123"
      }
    }, as: :json

    assert_response :ok

    json = response.parsed_body
    assert_equal "2fa_required", json["status"]
    assert_nil json["provisioning_uri"]

    # Verify admin was NOT signed in
    get internal_me_path, as: :json
    assert_response :unauthorized
  end

  test "POST login for admin cannot access admin pages before completing 2FA" do
    admin = create(:user, :admin, email: "admin@example.com", password: "password123")
    User::GenerateOtpSecret.(admin)
    User::EnableOtp.(admin)

    # Login - should return 2fa_required
    post user_session_path, params: {
      user: {
        email: "admin@example.com",
        password: "password123"
      }
    }, as: :json

    assert_response :ok
    assert_equal "2fa_required", response.parsed_body["status"]

    # Try to access admin page - should be unauthorized
    get admin_users_path, as: :json
    assert_response :unauthorized
    assert_equal "unauthorized", response.parsed_body["error"]["type"]
  end

  test "POST login for non-admin signs in normally" do
    post user_session_path, params: {
      user: {
        email: "test@example.com",
        password: "password123"
      }
    }, as: :json

    assert_response :ok
    assert_json_response({
      status: "success",
      user: SerializeUser.(@user)
    })

    # Verify user IS signed in
    get internal_me_path, as: :json
    assert_response :ok
  end
end
