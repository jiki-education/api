require "test_helper"

class Auth::ConfirmationsControllerTest < ApplicationControllerTest
  test "GET confirmation with valid token confirms user and signs them in" do
    user = create(:user, :unconfirmed)
    token = user.confirmation_token

    get user_confirmation_path(confirmation_token: token), as: :json

    assert_response :ok

    user.reload
    assert_json_response({
      status: "success",
      user: SerializeUser.(user)
    })

    # Verify user is now signed in
    get internal_me_path, as: :json
    assert_response :ok
  end

  test "GET confirmation with invalid token returns error" do
    get user_confirmation_path(confirmation_token: "invalid-token"), as: :json

    assert_response :unprocessable_entity

    json = response.parsed_body
    assert_equal "invalid_token", json["error"]["type"]
  end

  test "GET confirmation with already used token returns error" do
    user = create(:user, :unconfirmed)
    token = user.confirmation_token

    # Use the token once to confirm the user
    user.confirm

    # Try to use the same token again
    get user_confirmation_path(confirmation_token: token), as: :json

    assert_response :unprocessable_entity

    json = response.parsed_body
    assert_equal "invalid_token", json["error"]["type"]
  end

  test "POST confirmation resends confirmation email for valid email" do
    create(:user, :unconfirmed, email: "unconfirmed@example.com")

    assert_difference "ActionMailer::Base.deliveries.size", 1 do
      post user_confirmation_path, params: {
        user: { email: "unconfirmed@example.com" }
      }, as: :json
    end

    assert_response :ok

    json = response.parsed_body
    assert_equal "unconfirmed@example.com", json["user"]["email"]

    email = ActionMailer::Base.deliveries.last
    assert_equal ["unconfirmed@example.com"], email.to
    assert_includes email.subject.downcase, "confirm"
  end

  test "POST confirmation returns success even for unknown email" do
    # Security: don't reveal whether email exists
    post user_confirmation_path, params: {
      user: { email: "nonexistent@example.com" }
    }, as: :json

    assert_response :ok

    json = response.parsed_body
    assert_equal "nonexistent@example.com", json["user"]["email"]
  end

  test "POST confirmation returns success for already confirmed user" do
    create(:user, email: "confirmed@example.com") # Already confirmed

    # Should not send email but still return success
    post user_confirmation_path, params: {
      user: { email: "confirmed@example.com" }
    }, as: :json

    assert_response :ok

    json = response.parsed_body
    assert_equal "confirmed@example.com", json["user"]["email"]
  end
end
