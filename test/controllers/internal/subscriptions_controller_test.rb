require "test_helper"

class Internal::SubscriptionsControllerTest < ApplicationControllerTest
  setup do
    @user = create(:user)
    @headers = auth_headers_for(@user)
  end

  # Authentication guards
  guard_incorrect_token! :internal_subscriptions_checkout_session_path, method: :post
  guard_incorrect_token! :internal_subscriptions_verify_checkout_path, method: :post
  guard_incorrect_token! :internal_subscriptions_portal_session_path, method: :post
  guard_incorrect_token! :internal_subscriptions_status_path, method: :get

  ### checkout_session tests ###

  test "POST checkout_session creates session for premium product" do
    price_id = Jiki.config.stripe_premium_price_id
    return_url = "#{Jiki.config.frontend_base_url}/subscribe/complete"
    session = mock
    session.stubs(:client_secret).returns("cs_secret_123")

    Stripe::CreateCheckoutSession.expects(:call).with(@user, price_id, return_url).returns(session)

    post internal_subscriptions_checkout_session_path,
      params: { product: "premium", return_url: return_url },
      headers: @headers,
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
      headers: @headers,
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
      headers: @headers,
      as: :json

    assert_response :success
    json = response.parsed_body
    assert_equal "cs_secret_456", json["client_secret"]
  end

  test "POST checkout_session rejects invalid product" do
    return_url = "#{Jiki.config.frontend_base_url}/subscribe/complete"

    post internal_subscriptions_checkout_session_path,
      params: { product: "invalid", return_url: return_url },
      headers: @headers,
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
      headers: @headers,
      as: :json

    assert_response :bad_request
    json = response.parsed_body
    assert_equal "invalid_product", json["error"]["type"]
  end

  test "POST checkout_session rejects missing return_url" do
    post internal_subscriptions_checkout_session_path,
      params: { product: "premium" },
      headers: @headers,
      as: :json

    assert_response :bad_request
    json = response.parsed_body
    assert_equal "missing_return_url", json["error"]["type"]
    assert_equal "return_url is required", json["error"]["message"]
  end

  test "POST checkout_session handles Stripe errors gracefully" do
    return_url = "#{Jiki.config.frontend_base_url}/subscribe/complete"
    Jiki.config.stripe_premium_price_id

    Stripe::CreateCheckoutSession.expects(:call).raises(StandardError.new("Stripe API error"))

    post internal_subscriptions_checkout_session_path,
      params: { product: "premium", return_url: return_url },
      headers: @headers,
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
      headers: @headers,
      as: :json

    assert_response :success
  end

  test "POST checkout_session rejects invalid return_url" do
    post internal_subscriptions_checkout_session_path,
      params: { product: "premium", return_url: "https://evil.com/steal" },
      headers: @headers,
      as: :json

    assert_response :bad_request
    json = response.parsed_body
    assert_equal "invalid_return_url", json["error"]["type"]
    assert_match(/must start with/, json["error"]["message"])
  end

  ### verify_checkout tests ###

  test "POST verify_checkout successfully verifies and syncs subscription" do
    session_id = "cs_test_123"

    Stripe::VerifyCheckoutSession.expects(:call).with(@user, session_id).returns({
      success: true,
      tier: "premium"
    })

    post internal_subscriptions_verify_checkout_path,
      params: { session_id: },
      headers: @headers,
      as: :json

    assert_response :success
    json = response.parsed_body
    assert json["success"]
    assert_equal "premium", json["tier"]
  end

  test "POST verify_checkout returns error when session_id is missing" do
    post internal_subscriptions_verify_checkout_path,
      params: {},
      headers: @headers,
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
      headers: @headers,
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
      headers: @headers,
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
      headers: @headers,
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
      headers: @headers,
      as: :json

    assert_response :success
    json = response.parsed_body
    assert_equal "https://billing.stripe.com/session/abc", json["url"]
  end

  test "POST portal_session returns error when user has no stripe_customer_id" do
    assert_nil @user.data.stripe_customer_id

    post internal_subscriptions_portal_session_path,
      headers: @headers,
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
      headers: @headers,
      as: :json

    assert_response :internal_server_error
    json = response.parsed_body
    assert_equal "portal_failed", json["error"]["type"]
  end

  ### status tests ###

  test "GET status returns subscription data for standard user" do
    get internal_subscriptions_status_path,
      headers: @headers,
      as: :json

    assert_response :success
    json = response.parsed_body

    assert_equal "standard", json["subscription"]["tier"]
    assert_equal "none", json["subscription"]["status"]
    assert_nil json["subscription"]["current_period_end"]
    refute json["subscription"]["payment_failed"]
    refute json["subscription"]["in_grace_period"]
    assert_nil json["subscription"]["grace_period_ends_at"]
  end

  test "GET status returns subscription data for premium user with active subscription" do
    @user.data.update!(
      membership_type: "premium",
      stripe_subscription_status: "active",
      subscription_current_period_end: 1.month.from_now
    )

    get internal_subscriptions_status_path,
      headers: @headers,
      as: :json

    assert_response :success
    json = response.parsed_body

    assert_equal "premium", json["subscription"]["tier"]
    assert_equal "active", json["subscription"]["status"]
    refute_nil json["subscription"]["current_period_end"]
    refute json["subscription"]["payment_failed"]
    refute json["subscription"]["in_grace_period"]
  end

  test "GET status returns subscription data for user in grace period" do
    @user.data.update!(
      membership_type: "max",
      stripe_subscription_status: "past_due",
      payment_failed_at: 3.days.ago
    )

    get internal_subscriptions_status_path,
      headers: @headers,
      as: :json

    assert_response :success
    json = response.parsed_body

    assert_equal "max", json["subscription"]["tier"]
    assert_equal "past_due", json["subscription"]["status"]
    assert json["subscription"]["payment_failed"]
    assert json["subscription"]["in_grace_period"]
    refute_nil json["subscription"]["grace_period_ends_at"]
  end
end
