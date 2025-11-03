require "test_helper"

class Auth::PasswordsControllerTest < ApplicationControllerTest
  setup do
    @user = create(:user, email: "test@example.com", password: "oldpassword123")
  end

  test "POST password reset sends reset instructions" do
    post user_password_path, params: {
      user: {
        email: "test@example.com"
      }
    }, as: :json

    assert_response :ok

    json = response.parsed_body
    assert_equal "Reset instructions sent to test@example.com", json["message"]
  end

  test "POST password reset sends email with correct content and frontend URL" do
    # Mock config to have predictable URL
    Jiki.config.stubs(:frontend_base_url).returns("http://test.frontend.com")

    assert_emails 1 do
      post user_password_path, params: {
        user: {
          email: "test@example.com"
        }
      }, as: :json
    end

    mail = ActionMailer::Base.deliveries.last
    assert_equal ["test@example.com"], mail.to
    assert_equal "Reset Your Password", mail.subject

    # Check email contains frontend reset URL
    html_body = mail.html_part.body.to_s
    assert_match %r{http://test\.frontend\.com/auth/reset-password\?token=}, html_body
    assert_match "Reset My Password", html_body
  end

  test "POST password reset email respects user locale" do
    create(:user, :hungarian, email: "magyar@example.com", name: "József")

    post user_password_path, params: {
      user: {
        email: "magyar@example.com"
      }
    }, as: :json

    mail = ActionMailer::Base.deliveries.last
    assert_equal "Jelszó visszaállítása", mail.subject
    assert_match "Szia József,", mail.html_part.body.to_s
  end

  test "POST password reset with non-existent email still returns success (security)" do
    post user_password_path, params: {
      user: {
        email: "nonexistent@example.com"
      }
    }, as: :json

    assert_response :ok

    json = response.parsed_body
    assert_equal "Reset instructions sent to nonexistent@example.com", json["message"]
  end

  test "PATCH password reset updates password with valid token" do
    # Generate a reset token for the user
    token = @user.send_reset_password_instructions

    patch user_password_path, params: {
      user: {
        reset_password_token: token,
        password: "newpassword123",
        password_confirmation: "newpassword123"
      }
    }, as: :json

    assert_response :ok

    json = response.parsed_body
    assert_equal "Password has been reset successfully", json["message"]

    # Verify the user can login with new password
    post user_session_path, params: {
      user: {
        email: "test@example.com",
        password: "newpassword123"
      }
    }, as: :json

    assert_response :ok
  end

  test "PATCH password reset fails with invalid token" do
    patch user_password_path, params: {
      user: {
        reset_password_token: "invalid_token",
        password: "newpassword123",
        password_confirmation: "newpassword123"
      }
    }, as: :json

    assert_response :unprocessable_entity

    json = response.parsed_body
    assert_equal "invalid_token", json["error"]["type"]
    assert json["error"]["message"].present?
  end

  test "PATCH password reset fails with password mismatch" do
    token = @user.send_reset_password_instructions

    patch user_password_path, params: {
      user: {
        reset_password_token: token,
        password: "newpassword123",
        password_confirmation: "differentpassword"
      }
    }, as: :json

    assert_response :unprocessable_entity

    json = response.parsed_body
    assert_equal "invalid_token", json["error"]["type"]
    assert json["error"]["errors"]["password_confirmation"].present?
  end

  test "PATCH password reset fails with short password" do
    token = @user.send_reset_password_instructions

    patch user_password_path, params: {
      user: {
        reset_password_token: token,
        password: "short",
        password_confirmation: "short"
      }
    }, as: :json

    assert_response :unprocessable_entity

    json = response.parsed_body
    assert_equal "invalid_token", json["error"]["type"]
    assert json["error"]["errors"]["password"].present?
  end
end
