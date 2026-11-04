require "test_helper"

class Internal::PremiumPurchasesControllerTest < ApplicationControllerTest
  setup do
    @user = create(:user)
    sign_in_user(@user)
    @return_url = "#{Jiki.config.frontend_base_url}/premium/complete"
  end

  guard_incorrect_token! :internal_premium_purchases_checkout_session_path, method: :post
  guard_incorrect_token! :internal_premium_purchases_verify_checkout_path, method: :post

  ### checkout_session ###

  test "POST checkout_session returns the decoded client secret" do
    Stripe::PremiumPurchase::CreateCheckoutSession.expects(:call).
      with(@user, @return_url, :usd).
      returns(stub(client_secret: "cs_secret%5F123"))

    post internal_premium_purchases_checkout_session_path, params: { return_url: @return_url }, as: :json

    assert_response :success
    assert_json_response({ client_secret: "cs_secret_123" })
  end

  test "POST checkout_session tracks checkout_started" do
    Stripe::PremiumPurchase::CreateCheckoutSession.stubs(:call).returns(stub(client_secret: "cs_secret"))

    Analytics::TrackEvent.expects(:defer).with(
      @user,
      "checkout_started",
      properties: { plan: "premium", interval: "lifetime", currency: :usd, trigger: "upgrade_cta_nav" }
    )

    post internal_premium_purchases_checkout_session_path,
      params: { return_url: @return_url, trigger: "upgrade_cta_nav" },
      as: :json

    assert_response :success
  end

  test "POST checkout_session rejects a user who already has premium" do
    create(:premium_entitlement, :stripe, user: @user)
    Stripe::PremiumPurchase::CreateCheckoutSession.expects(:call).never

    post internal_premium_purchases_checkout_session_path, params: { return_url: @return_url }, as: :json

    assert_response :bad_request
    assert_json_response({ error: { type: "already_premium" } })
  end

  test "POST checkout_session rejects a user whose purchase is still clearing" do
    @user.data.update!(pending_premium_purchase_payment_intent_id: "pi_123", pending_premium_purchase_at: 1.day.ago)
    Stripe::PremiumPurchase::CreateCheckoutSession.expects(:call).never
    Sentry.expects(:capture_message).never

    post internal_premium_purchases_checkout_session_path, params: { return_url: @return_url }, as: :json

    assert_response :bad_request
    assert_json_response({ error: { type: "purchase_pending" } })
  end

  test "POST checkout_session rejects a live legacy subscriber" do
    @user.data.update!(subscription_status: "active")
    Stripe::PremiumPurchase::CreateCheckoutSession.expects(:call).never

    post internal_premium_purchases_checkout_session_path, params: { return_url: @return_url }, as: :json

    assert_response :bad_request
    assert_json_response({ error: { type: "already_premium" } })
  end

  test "POST checkout_session rejects a non-frontend return_url" do
    Stripe::PremiumPurchase::CreateCheckoutSession.expects(:call).never

    post internal_premium_purchases_checkout_session_path,
      params: { return_url: "https://evil.example.com" },
      as: :json

    assert_response :bad_request
    assert_json_response({ error: { type: "invalid_return_url" } })
  end

  test "POST checkout_session handles Stripe failures" do
    Stripe::PremiumPurchase::CreateCheckoutSession.stubs(:call).raises(::Stripe::APIConnectionError.new("boom"))

    post internal_premium_purchases_checkout_session_path, params: { return_url: @return_url }, as: :json

    assert_response :internal_server_error
    assert_json_response({ error: { type: "checkout_failed" } })
  end

  ### verify_checkout ###

  test "POST verify_checkout returns the payment state" do
    Stripe::PremiumPurchase::VerifyCheckoutSession.expects(:call).
      with(@user, "cs_123").
      returns({ success: true, payment_state: "paid" })

    post internal_premium_purchases_verify_checkout_path, params: { session_id: "cs_123" }, as: :json

    assert_response :success
    assert_json_response({ success: true, payment_state: "paid" })
  end

  test "POST verify_checkout requires a session_id" do
    post internal_premium_purchases_verify_checkout_path, as: :json

    assert_response :bad_request
    assert_json_response({ error: { type: "missing_session_id" } })
  end

  test "POST verify_checkout rejects another user's session" do
    Stripe::PremiumPurchase::VerifyCheckoutSession.stubs(:call).raises(SecurityError)

    post internal_premium_purchases_verify_checkout_path, params: { session_id: "cs_123" }, as: :json

    assert_response :forbidden
    assert_json_response({ error: { type: "unauthorized" } })
  end

  test "POST verify_checkout reports an incomplete payment" do
    Stripe::PremiumPurchase::VerifyCheckoutSession.stubs(:call).
      raises(StripeCheckoutSessionIncompleteError.new(decline_code: "expired_card", currency: "gbp"))

    post internal_premium_purchases_verify_checkout_path, params: { session_id: "cs_123" }, as: :json

    assert_response :unprocessable_entity
    assert_json_response({ error: { type: "checkout_payment_incomplete", decline_code: "expired_card", currency: "gbp" } })
  end

  test "POST verify_checkout rejects an invalid session" do
    Stripe::PremiumPurchase::VerifyCheckoutSession.stubs(:call).raises(ArgumentError)

    post internal_premium_purchases_verify_checkout_path, params: { session_id: "cs_123" }, as: :json

    assert_response :unprocessable_entity
    assert_json_response({ error: { type: "invalid_session" } })
  end

  test "POST verify_checkout handles unexpected failures" do
    Stripe::PremiumPurchase::VerifyCheckoutSession.stubs(:call).raises(::Stripe::APIConnectionError.new("boom"))

    post internal_premium_purchases_verify_checkout_path, params: { session_id: "cs_123" }, as: :json

    assert_response :internal_server_error
    assert_json_response({ error: { type: "verification_failed" } })
  end
end
