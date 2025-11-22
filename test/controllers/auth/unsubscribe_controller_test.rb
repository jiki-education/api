require "test_helper"

class Auth::UnsubscribeControllerTest < ApplicationControllerTest
  test "POST create unsubscribes user with valid token" do
    user = create(:user, email: "test@example.com")
    token = user.data.unsubscribe_token

    freeze_time do
      post auth_unsubscribe_path(token), as: :json

      assert_response :ok

      json = response.parsed_body
      assert json["unsubscribed"]
      assert_equal "test@example.com", json["email"]

      # Verify user was actually unsubscribed
      user.reload
      assert_equal Time.current, user.data.email_complaint_at
      assert_equal 'unsubscribe_rfc_8058', user.data.email_complaint_type
    end
  end

  test "POST create returns proper JSON structure on success" do
    user = create(:user, email: "success@example.com")
    token = user.data.unsubscribe_token

    post auth_unsubscribe_path(token), as: :json

    assert_response :ok

    json = response.parsed_body
    assert json.key?("unsubscribed")
    assert json.key?("email")
    assert json.key?("meta")
    # Should have unsubscribed, email, and meta keys
    assert_equal %w[unsubscribed email meta].sort, json.keys.sort
  end

  test "POST create returns 404 for invalid token" do
    post auth_unsubscribe_path("invalid-token-that-does-not-exist"), as: :json

    assert_response :not_found

    json = response.parsed_body
    assert_equal "Invalid or expired unsubscribe token", json["error"]
  end

  test "POST create returns 404 for empty string token" do
    post auth_unsubscribe_path("empty"), as: :json

    assert_response :not_found

    json = response.parsed_body
    assert json.key?("error")
  end

  test "POST create returns 404 for non-existent user token" do
    # Create a token format that looks valid but doesn't belong to any user
    fake_token = SecureRandom.uuid

    post auth_unsubscribe_path(fake_token), as: :json

    assert_response :not_found
  end

  test "POST create does not require authentication" do
    user = create(:user)
    token = user.data.unsubscribe_token

    # Make request without any Authorization header
    post auth_unsubscribe_path(token), as: :json

    assert_response :ok
    json = response.parsed_body
    assert json["unsubscribed"]
  end

  test "POST create can be called multiple times for same token" do
    user = create(:user, email: "multi@example.com")
    token = user.data.unsubscribe_token

    # First call
    post auth_unsubscribe_path(token), as: :json
    assert_response :ok

    # Second call - should still work
    post auth_unsubscribe_path(token), as: :json
    assert_response :ok

    json = response.parsed_body
    assert json["unsubscribed"]
    assert_equal "multi@example.com", json["email"]
  end
end
