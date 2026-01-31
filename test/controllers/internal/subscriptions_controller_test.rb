require "test_helper"

class Internal::SubscriptionsControllerTest < ApplicationControllerTest
  setup do
    @user = create(:user)
    sign_in_user(@user)
  end

  # Authentication guards
  guard_incorrect_token! :internal_subscriptions_checkout_session_path, method: :post
  guard_incorrect_token! :internal_subscriptions_verify_checkout_path, method: :post
  guard_incorrect_token! :internal_subscriptions_portal_session_path, method: :post
  guard_incorrect_token! :internal_subscriptions_update_path, method: :post
  guard_incorrect_token! :internal_subscriptions_cancel_path, method: :delete
  guard_incorrect_token! :internal_subscriptions_reactivate_path, method: :post

  ### checkout_session tests ###

  test "POST checkout_session creates session for premium product" do
    price_id = Jiki.config.stripe_premium_price_id
    return_url = "#{Jiki.config.frontend_base_url}/subscribe/complete"
    session = mock
    session.stubs(:client_secret).returns("cs_secret_123")

    Stripe::CreateCheckoutSession.expects(:call).with(@user, price_id, return_url).returns(session)

    post internal_subscriptions_checkout_session_path,
      params: { product: "premium", return_url: return_url },
      as: :json

    assert_response :success
    json = response.parsed_body
    assert_equal "cs_secret_123", json["client_secret"]
  end

  test "POST checkout_session URL-decodes client_secret from Stripe" do
    price_id = Jiki.config.stripe_premium_price_id
    return_url = "#{Jiki.config.frontend_base_url}/subscribe/complete"

    # Stripe Ruby gem returns URL-encoded client_secret with %2F instead of /
    url_encoded_secret = "cs_test_abc_secret_abc%2Fdef%2Bghi"
    expected_decoded = "cs_test_abc_secret_abc/def+ghi"

    session = mock
    session.stubs(:client_secret).returns(url_encoded_secret)

    Stripe::CreateCheckoutSession.expects(:call).with(@user, price_id, return_url).returns(session)

    post internal_subscriptions_checkout_session_path,
      params: { product: "premium", return_url: return_url },
      as: :json

    assert_response :success
    json = response.parsed_body
    assert_equal expected_decoded, json["client_secret"]
    refute_includes json["client_secret"], "%2F", "client_secret should not contain URL-encoded characters"
    assert_includes json["client_secret"], "/", "client_secret should contain decoded forward slashes"
  end

  test "POST checkout_session creates session for max product" do
    price_id = Jiki.config.stripe_max_price_id
    return_url = "#{Jiki.config.frontend_base_url}/subscribe/complete"
    session = mock
    session.stubs(:client_secret).returns("cs_secret_456")

    Stripe::CreateCheckoutSession.expects(:call).with(@user, price_id, return_url).returns(session)

    post internal_subscriptions_checkout_session_path,
      params: { product: "max", return_url: return_url },
      as: :json

    assert_response :success
    json = response.parsed_body
    assert_equal "cs_secret_456", json["client_secret"]
  end

  test "POST checkout_session rejects invalid product" do
    return_url = "#{Jiki.config.frontend_base_url}/subscribe/complete"

    post internal_subscriptions_checkout_session_path,
      params: { product: "invalid", return_url: return_url },
      as: :json

    assert_response :bad_request
    json = response.parsed_body
    assert_equal "invalid_product", json["error"]["type"]
    assert_equal "Invalid product. Must be 'premium' or 'max'", json["error"]["message"]
  end

  test "POST checkout_session rejects missing product" do
    return_url = "#{Jiki.config.frontend_base_url}/subscribe/complete"

    post internal_subscriptions_checkout_session_path,
      params: { return_url: return_url },
      as: :json

    assert_response :bad_request
    json = response.parsed_body
    assert_equal "invalid_product", json["error"]["type"]
  end

  test "POST checkout_session rejects missing return_url" do
    post internal_subscriptions_checkout_session_path,
      params: { product: "premium" },
      as: :json

    assert_response :bad_request
    json = response.parsed_body
    assert_equal "invalid_return_url", json["error"]["type"]
    assert_match(/must be from/, json["error"]["message"])
  end

  test "POST checkout_session handles Stripe errors gracefully" do
    return_url = "#{Jiki.config.frontend_base_url}/subscribe/complete"
    Jiki.config.stripe_premium_price_id

    Stripe::CreateCheckoutSession.expects(:call).raises(StandardError.new("Stripe API error"))

    post internal_subscriptions_checkout_session_path,
      params: { product: "premium", return_url: return_url },
      as: :json

    assert_response :internal_server_error
    json = response.parsed_body
    assert_equal "checkout_failed", json["error"]["type"]
  end

  test "POST checkout_session accepts valid return_url" do
    price_id = Jiki.config.stripe_premium_price_id
    return_url = "#{Jiki.config.frontend_base_url}/custom/path"
    session = mock
    session.stubs(:client_secret).returns("cs_secret_123")

    Stripe::CreateCheckoutSession.expects(:call).with(@user, price_id, return_url).returns(session)

    post internal_subscriptions_checkout_session_path,
      params: { product: "premium", return_url: return_url },
      as: :json

    assert_response :success
  end

  test "POST checkout_session rejects invalid return_url" do
    post internal_subscriptions_checkout_session_path,
      params: { product: "premium", return_url: "https://evil.com/steal" },
      as: :json

    assert_response :bad_request
    json = response.parsed_body
    assert_equal "invalid_return_url", json["error"]["type"]
    assert_match(/must be from/, json["error"]["message"])
  end

  test "POST checkout_session rejects subdomain bypass attempt" do
    frontend_base_url = Jiki.config.frontend_base_url
    uri = URI.parse(frontend_base_url)
    bypass_url = "#{uri.scheme}://#{uri.host}.evil.com/callback"

    post internal_subscriptions_checkout_session_path,
      params: { product: "premium", return_url: bypass_url },
      as: :json

    assert_response :bad_request
    json = response.parsed_body
    assert_equal "invalid_return_url", json["error"]["type"]
  end

  test "POST checkout_session rejects URL with different scheme" do
    frontend_base_url = Jiki.config.frontend_base_url
    uri = URI.parse(frontend_base_url)
    different_scheme = uri.scheme == "https" ? "http" : "https"
    bypass_url = "#{different_scheme}://#{uri.host}/callback"

    post internal_subscriptions_checkout_session_path,
      params: { product: "premium", return_url: bypass_url },
      as: :json

    assert_response :bad_request
    json = response.parsed_body
    assert_equal "invalid_return_url", json["error"]["type"]
  end

  test "POST checkout_session rejects URL with userinfo in host" do
    frontend_base_url = Jiki.config.frontend_base_url
    uri = URI.parse(frontend_base_url)
    bypass_url = "#{uri.scheme}://evil.com@#{uri.host}/callback"

    post internal_subscriptions_checkout_session_path,
      params: { product: "premium", return_url: bypass_url },
      as: :json

    assert_response :bad_request
    json = response.parsed_body
    assert_equal "invalid_return_url", json["error"]["type"]
  end

  ### verify_checkout tests ###

  test "POST verify_checkout successfully verifies and syncs subscription" do
    session_id = "cs_test_123"

    Stripe::VerifyCheckoutSession.expects(:call).with(@user, session_id).returns({
      success: true,
      tier: "premium",
      payment_status: "paid",
      subscription_status: "active"
    })

    post internal_subscriptions_verify_checkout_path,
      params: { session_id: },
      as: :json

    assert_response :success
    json = response.parsed_body
    assert json["success"]
    assert_equal "premium", json["tier"]
    assert_equal "paid", json["payment_status"]
    assert_equal "active", json["subscription_status"]
  end

  test "POST verify_checkout returns incomplete status for async payments" do
    session_id = "cs_test_123"

    Stripe::VerifyCheckoutSession.expects(:call).with(@user, session_id).returns({
      success: true,
      tier: "premium",
      payment_status: "unpaid",
      subscription_status: "incomplete"
    })

    post internal_subscriptions_verify_checkout_path,
      params: { session_id: },
      as: :json

    assert_response :success
    json = response.parsed_body
    assert json["success"]
    assert_equal "premium", json["tier"]
    assert_equal "unpaid", json["payment_status"]
    assert_equal "incomplete", json["subscription_status"]
  end

  test "POST verify_checkout returns error when session_id is missing" do
    post internal_subscriptions_verify_checkout_path,
      params: {},
      as: :json

    assert_response :bad_request
    json = response.parsed_body
    assert_equal "missing_session_id", json["error"]["type"]
    assert_equal "session_id is required", json["error"]["message"]
  end

  test "POST verify_checkout returns forbidden when session does not belong to user" do
    session_id = "cs_test_123"

    Stripe::VerifyCheckoutSession.expects(:call).
      with(@user, session_id).
      raises(SecurityError.new("Checkout session does not belong to current user"))

    post internal_subscriptions_verify_checkout_path,
      params: { session_id: },
      as: :json

    assert_response :forbidden
    json = response.parsed_body
    assert_equal "unauthorized", json["error"]["type"]
  end

  test "POST verify_checkout returns unprocessable_entity for invalid session" do
    session_id = "cs_test_123"

    Stripe::VerifyCheckoutSession.expects(:call).
      with(@user, session_id).
      raises(ArgumentError.new("Checkout session is not complete"))

    post internal_subscriptions_verify_checkout_path,
      params: { session_id: },
      as: :json

    assert_response :unprocessable_entity
    json = response.parsed_body
    assert_equal "invalid_session", json["error"]["type"]
  end

  test "POST verify_checkout handles general errors gracefully" do
    session_id = "cs_test_123"

    Stripe::VerifyCheckoutSession.expects(:call).
      with(@user, session_id).
      raises(StandardError.new("Stripe API error"))

    post internal_subscriptions_verify_checkout_path,
      params: { session_id: },
      as: :json

    assert_response :internal_server_error
    json = response.parsed_body
    assert_equal "verification_failed", json["error"]["type"]
  end

  ### portal_session tests ###

  test "POST portal_session creates session when user has stripe_customer_id" do
    @user.data.update!(stripe_customer_id: "cus_123")

    session = mock
    session.stubs(:url).returns("https://billing.stripe.com/session/abc")

    Stripe::CreatePortalSession.expects(:call).with(@user).returns(session)

    post internal_subscriptions_portal_session_path,
      as: :json

    assert_response :success
    json = response.parsed_body
    assert_equal "https://billing.stripe.com/session/abc", json["url"]
  end

  test "POST portal_session returns error when user has no stripe_customer_id" do
    assert_nil @user.data.stripe_customer_id

    post internal_subscriptions_portal_session_path,
      as: :json

    assert_response :bad_request
    json = response.parsed_body
    assert_equal "no_customer", json["error"]["type"]
    assert_equal "No Stripe customer found", json["error"]["message"]
  end

  test "POST portal_session handles Stripe errors gracefully" do
    @user.data.update!(stripe_customer_id: "cus_123")

    Stripe::CreatePortalSession.expects(:call).raises(StandardError.new("Stripe API error"))

    post internal_subscriptions_portal_session_path,
      as: :json

    assert_response :internal_server_error
    json = response.parsed_body
    assert_equal "portal_failed", json["error"]["type"]
  end

  ### update tests ###

  test "POST update upgrades from premium to max" do
    @user.data.update!(
      membership_type: "premium",
      stripe_subscription_id: "sub_123",
      subscription_status: "active"
    )

    result = {
      success: true,
      tier: "max",
      effective_at: "immediate",
      subscription_valid_until: 1.month.from_now
    }

    Stripe::UpdateSubscription.expects(:call).with(@user, "max").returns(result)

    post internal_subscriptions_update_path,
      params: { product: "max" },
      as: :json

    assert_response :success
    json = response.parsed_body
    assert json["success"]
    assert_equal "max", json["tier"]
    assert_equal "immediate", json["effective_at"]
    refute_nil json["subscription_valid_until"]
  end

  test "POST update downgrades from max to premium" do
    @user.data.update!(
      membership_type: "max",
      stripe_subscription_id: "sub_123",
      subscription_status: "active"
    )

    Stripe::UpdateSubscription.expects(:call).with(@user, "premium").returns({
      success: true,
      tier: "premium"
    })

    post internal_subscriptions_update_path,
      params: { product: "premium" },
      as: :json

    assert_response :success
    json = response.parsed_body
    assert json["success"]
    assert_equal "premium", json["tier"]
  end

  test "POST update allows tier change for payment_failed status" do
    @user.data.update!(
      membership_type: "premium",
      stripe_subscription_id: "sub_123",
      subscription_status: "payment_failed"
    )

    Stripe::UpdateSubscription.expects(:call).with(@user, "max").returns({})

    post internal_subscriptions_update_path,
      params: { product: "max" },
      as: :json

    assert_response :success
  end

  test "POST update allows tier change for cancelling status" do
    @user.data.update!(
      membership_type: "premium",
      stripe_subscription_id: "sub_123",
      subscription_status: "cancelling"
    )

    Stripe::UpdateSubscription.expects(:call).with(@user, "max").returns({})

    post internal_subscriptions_update_path,
      params: { product: "max" },
      as: :json

    assert_response :success
  end

  test "POST update rejects invalid product" do
    @user.data.update!(
      membership_type: "premium",
      stripe_subscription_id: "sub_123",
      subscription_status: "active"
    )

    post internal_subscriptions_update_path,
      params: { product: "invalid" },
      as: :json

    assert_response :bad_request
    json = response.parsed_body
    assert_equal "invalid_product", json["error"]["type"]
    assert_equal "Invalid product. Must be 'premium' or 'max'", json["error"]["message"]
  end

  test "POST update rejects same tier" do
    @user.data.update!(
      membership_type: "premium",
      stripe_subscription_id: "sub_123",
      subscription_status: "active"
    )

    post internal_subscriptions_update_path,
      params: { product: "premium" },
      as: :json

    assert_response :bad_request
    json = response.parsed_body
    assert_equal "same_tier", json["error"]["type"]
    assert_equal "You are already subscribed to premium", json["error"]["message"]
  end

  test "POST update rejects when user cannot change tier" do
    @user.data.update!(
      membership_type: "standard",
      subscription_status: "never_subscribed"
    )

    post internal_subscriptions_update_path,
      params: { product: "premium" },
      as: :json

    assert_response :bad_request
    json = response.parsed_body
    assert_equal "no_subscription", json["error"]["type"]
  end

  test "POST update rejects when user is canceled" do
    @user.data.update!(
      membership_type: "standard",
      subscription_status: "canceled"
    )

    post internal_subscriptions_update_path,
      params: { product: "premium" },
      as: :json

    assert_response :bad_request
    json = response.parsed_body
    assert_equal "no_subscription", json["error"]["type"]
  end

  test "POST update handles Stripe errors gracefully" do
    @user.data.update!(
      membership_type: "premium",
      stripe_subscription_id: "sub_123",
      subscription_status: "active"
    )

    Stripe::UpdateSubscription.expects(:call).raises(StandardError.new("Stripe API error"))

    post internal_subscriptions_update_path,
      params: { product: "max" },
      as: :json

    assert_response :internal_server_error
    json = response.parsed_body
    assert_equal "update_failed", json["error"]["type"]
  end

  test "POST update handles ArgumentError gracefully" do
    @user.data.update!(
      membership_type: "premium",
      stripe_subscription_id: "sub_123",
      subscription_status: "active"
    )

    Stripe::UpdateSubscription.expects(:call).raises(ArgumentError.new("Invalid subscription"))

    post internal_subscriptions_update_path,
      params: { product: "max" },
      as: :json

    assert_response :unprocessable_entity
    json = response.parsed_body
    assert_equal "invalid_request", json["error"]["type"]
  end

  ### cancel tests ###

  test "DELETE cancel cancels active subscription" do
    @user.data.update!(
      membership_type: "premium",
      stripe_subscription_id: "sub_123",
      subscription_status: "active"
    )

    cancels_at = 1.month.from_now
    result = {
      success: true,
      cancels_at: cancels_at
    }

    Stripe::CancelSubscription.expects(:call).with(@user).returns(result)

    delete internal_subscriptions_cancel_path,
      as: :json

    assert_response :success
    json = response.parsed_body
    assert json["success"]
    refute_nil json["cancels_at"]
  end

  test "DELETE cancel works for payment_failed subscription" do
    @user.data.update!(
      membership_type: "premium",
      stripe_subscription_id: "sub_123",
      subscription_status: "payment_failed"
    )

    Stripe::CancelSubscription.expects(:call).with(@user).returns({})

    delete internal_subscriptions_cancel_path,
      as: :json

    assert_response :success
  end

  test "DELETE cancel works for incomplete subscription" do
    @user.data.update!(
      membership_type: "standard",
      stripe_subscription_id: "sub_123",
      subscription_status: "incomplete"
    )

    Stripe::CancelSubscription.expects(:call).with(@user).returns({})

    delete internal_subscriptions_cancel_path,
      as: :json

    assert_response :success
  end

  test "DELETE cancel rejects when no subscription" do
    @user.data.update!(
      membership_type: "standard",
      stripe_subscription_id: nil,
      subscription_status: "never_subscribed"
    )

    delete internal_subscriptions_cancel_path,
      as: :json

    assert_response :bad_request
    json = response.parsed_body
    assert_equal "no_subscription", json["error"]["type"]
    assert_equal "You don't have an active subscription", json["error"]["message"]
  end

  test "DELETE cancel rejects when subscription already canceled" do
    @user.data.update!(
      membership_type: "standard",
      stripe_subscription_id: nil,
      subscription_status: "canceled"
    )

    delete internal_subscriptions_cancel_path,
      as: :json

    assert_response :bad_request
    json = response.parsed_body
    assert_equal "no_subscription", json["error"]["type"]
  end

  test "DELETE cancel handles Stripe errors gracefully" do
    @user.data.update!(
      membership_type: "premium",
      stripe_subscription_id: "sub_123",
      subscription_status: "active"
    )

    Stripe::CancelSubscription.expects(:call).raises(StandardError.new("Stripe API error"))

    delete internal_subscriptions_cancel_path,
      as: :json

    assert_response :internal_server_error
    json = response.parsed_body
    assert_equal "cancel_failed", json["error"]["type"]
  end

  ### reactivate tests ###

  test "POST reactivate reactivates canceled subscription" do
    period_end = 1.month.from_now
    @user.data.update!(
      membership_type: "premium",
      stripe_subscription_id: "sub_123",
      subscription_status: "cancelling",
      subscription_valid_until: period_end
    )

    result = {
      success: true,
      subscription_valid_until: period_end
    }

    Stripe::ReactivateSubscription.expects(:call).with(@user).returns(result)

    post internal_subscriptions_reactivate_path,
      as: :json

    assert_response :success
    json = response.parsed_body
    assert json["success"]
    refute_nil json["subscription_valid_until"]
  end

  test "POST reactivate rejects when no subscription" do
    @user.data.update!(
      membership_type: "standard",
      stripe_subscription_id: nil,
      subscription_status: "never_subscribed"
    )

    post internal_subscriptions_reactivate_path,
      as: :json

    assert_response :bad_request
    json = response.parsed_body
    assert_equal "no_subscription", json["error"]["type"]
    assert_equal "You don't have an active subscription", json["error"]["message"]
  end

  test "POST reactivate rejects when subscription is not cancelling" do
    @user.data.update!(
      membership_type: "premium",
      stripe_subscription_id: "sub_123",
      subscription_status: "active"
    )

    post internal_subscriptions_reactivate_path,
      as: :json

    assert_response :bad_request
    json = response.parsed_body
    assert_equal "not_cancelling", json["error"]["type"]
    assert_equal "Subscription is not scheduled for cancellation", json["error"]["message"]
  end

  test "POST reactivate handles command ArgumentError" do
    @user.data.update!(
      membership_type: "premium",
      stripe_subscription_id: "sub_123",
      subscription_status: "cancelling"
    )

    Stripe::ReactivateSubscription.expects(:call).raises(ArgumentError.new("Custom error"))

    post internal_subscriptions_reactivate_path,
      as: :json

    assert_response :unprocessable_entity
    json = response.parsed_body
    assert_equal "invalid_request", json["error"]["type"]
    assert_equal "Custom error", json["error"]["message"]
  end

  test "POST reactivate handles Stripe errors gracefully" do
    @user.data.update!(
      membership_type: "premium",
      stripe_subscription_id: "sub_123",
      subscription_status: "cancelling"
    )

    Stripe::ReactivateSubscription.expects(:call).raises(StandardError.new("Stripe API error"))

    post internal_subscriptions_reactivate_path,
      as: :json

    assert_response :internal_server_error
    json = response.parsed_body
    assert_equal "reactivate_failed", json["error"]["type"]
  end
end
