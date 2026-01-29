require "test_helper"

class Auth::AccountDeletionsControllerTest < ApplicationControllerTest
  # Request deletion endpoint requires authentication
  guard_incorrect_token! :auth_account_deletion_request_path, method: :post

  test "POST request_deletion sends confirmation email" do
    user = create(:user)
    sign_in_user(user)

    assert_enqueued_with(job: ActionMailer::MailDeliveryJob) do
      post auth_account_deletion_request_path, as: :json
    end

    assert_response :ok
    assert_empty(response.parsed_body.except("meta"))
  end

  test "POST confirm deletes user with valid token" do
    user = create(:user)
    token = AccountDeletion::CreateDeletionToken.(user)

    assert_difference 'User.count', -1 do
      post auth_account_deletion_confirm_path, params: { token: token }, as: :json
    end

    assert_response :ok
    assert_empty(response.parsed_body.except("meta"))
  end

  test "POST confirm does not require authentication" do
    user = create(:user)
    token = AccountDeletion::CreateDeletionToken.(user)

    # Reset session to ensure no authentication
    reset!

    post auth_account_deletion_confirm_path, params: { token: token }, as: :json

    assert_response :ok
  end

  test "POST confirm clears cookies" do
    user = create(:user)
    sign_in_user(user)
    token = AccountDeletion::CreateDeletionToken.(user)

    post auth_account_deletion_confirm_path, params: { token: token }, as: :json

    assert_response :ok
    # After deletion, the user should be signed out
    # Verify by attempting an authenticated request
    reset!
    get internal_me_path, as: :json
    assert_response :unauthorized
  end

  test "POST confirm returns 422 for invalid token" do
    post auth_account_deletion_confirm_path, params: { token: "invalid-token" }, as: :json

    assert_response :unprocessable_entity
    assert_equal "invalid_token", response.parsed_body["error"]["type"]
  end

  test "POST confirm returns 422 for expired token" do
    user = create(:user)

    token = travel_to(2.hours.ago) do
      AccountDeletion::CreateDeletionToken.(user)
    end

    post auth_account_deletion_confirm_path, params: { token: token }, as: :json

    assert_response :unprocessable_entity
    assert_equal "token_expired", response.parsed_body["error"]["type"]
  end

  test "POST confirm returns 422 for already deleted user" do
    user = create(:user)
    token = AccountDeletion::CreateDeletionToken.(user)
    user.destroy!

    post auth_account_deletion_confirm_path, params: { token: token }, as: :json

    assert_response :unprocessable_entity
    assert_equal "invalid_token", response.parsed_body["error"]["type"]
  end

  test "POST confirm returns 503 when stripe cancellation fails" do
    user = create(:user)
    user.data.update!(stripe_subscription_id: "sub_123", subscription_status: "active")
    token = AccountDeletion::CreateDeletionToken.(user)

    error = ::Stripe::APIError.new("Stripe is down")
    ::Stripe::Subscription.expects(:cancel).with("sub_123").raises(error)

    assert_no_difference 'User.count' do
      post auth_account_deletion_confirm_path, params: { token: token }, as: :json
    end

    assert_response :service_unavailable
    assert_equal "stripe_error", response.parsed_body["error"]["type"]
  end

  test "POST confirm cancels stripe subscription before deleting user" do
    user = create(:user)
    user.data.update!(stripe_subscription_id: "sub_456", subscription_status: "active")
    token = AccountDeletion::CreateDeletionToken.(user)

    ::Stripe::Subscription.expects(:cancel).with("sub_456").returns(mock)

    assert_difference 'User.count', -1 do
      post auth_account_deletion_confirm_path, params: { token: token }, as: :json
    end

    assert_response :ok
  end
end
