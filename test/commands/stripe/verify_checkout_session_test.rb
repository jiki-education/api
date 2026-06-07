require "test_helper"

class Stripe::VerifyCheckoutSessionTest < ActiveSupport::TestCase
  test "verifies checkout session for monthly subscription" do
    user = create(:user)
    user.data.update!(stripe_customer_id: "cus_123")
    session_id = "cs_test_123"

    stripe_session = mock_stripe_session
    stripe_subscription = mock_stripe_subscription(price_id: Jiki.config.stripe_premium_monthly_price_id)

    ::Stripe::Checkout::Session.expects(:retrieve).with(session_id).returns(stripe_session)
    ::Stripe::Subscription.expects(:retrieve).with("sub_123").returns(stripe_subscription)

    result = Stripe::VerifyCheckoutSession.(user, session_id)

    assert result[:success]
    assert_equal "monthly", result[:interval]
    assert_equal "paid", result[:payment_status]
    assert_equal "active", result[:subscription_status]

    user.data.reload
    assert_equal "premium", user.data.membership_type
    assert_equal "monthly", user.data.subscription_interval
    assert_equal "sub_123", user.data.stripe_subscription_id
    assert_equal "active", user.data.subscription_status
    refute_nil user.data.subscription_valid_until
    assert_equal 1, user.data.subscriptions.length
  end

  test "verifies checkout session for annual subscription" do
    skip "annual checkout disabled until FE wires it up"
    user = create(:user)
    user.data.update!(stripe_customer_id: "cus_123")
    session_id = "cs_test_123"

    stripe_session = mock_stripe_session
    stripe_subscription = mock_stripe_subscription(price_id: Jiki.config.stripe_premium_annual_price_id)

    ::Stripe::Checkout::Session.expects(:retrieve).with(session_id).returns(stripe_session)
    ::Stripe::Subscription.expects(:retrieve).with("sub_123").returns(stripe_subscription)

    result = Stripe::VerifyCheckoutSession.(user, session_id)

    assert result[:success]
    assert_equal "annual", result[:interval]

    user.data.reload
    assert_equal "premium", user.data.membership_type
    assert_equal "annual", user.data.subscription_interval
  end

  test "raises SecurityError when session customer does not match user" do
    user = create(:user)
    user.data.update!(stripe_customer_id: "cus_123")

    stripe_session = mock
    stripe_session.stubs(:metadata).returns(nil)
    stripe_session.stubs(:customer).returns("cus_different")

    ::Stripe::Checkout::Session.expects(:retrieve).with("cs_test_123").returns(stripe_session)

    assert_raises(SecurityError) do
      Stripe::VerifyCheckoutSession.(user, "cs_test_123")
    end
  end

  test "raises ArgumentError when session is not complete" do
    user = create(:user)
    user.data.update!(stripe_customer_id: "cus_123")

    stripe_session = mock
    stripe_session.stubs(:metadata).returns(nil)
    stripe_session.stubs(:customer).returns("cus_123")
    stripe_session.stubs(:status).returns("open")

    ::Stripe::Checkout::Session.expects(:retrieve).with("cs_test_123").returns(stripe_session)

    error = assert_raises(ArgumentError) do
      Stripe::VerifyCheckoutSession.(user, "cs_test_123")
    end
    assert_match(/not complete/, error.message)
  end

  test "raises ArgumentError when session has no subscription" do
    user = create(:user)
    user.data.update!(stripe_customer_id: "cus_123")

    stripe_session = mock
    stripe_session.stubs(:metadata).returns(nil)
    stripe_session.stubs(:customer).returns("cus_123")
    stripe_session.stubs(:status).returns("complete")
    stripe_session.stubs(:subscription).returns(nil)

    ::Stripe::Checkout::Session.expects(:retrieve).with("cs_test_123").returns(stripe_session)

    error = assert_raises(ArgumentError) do
      Stripe::VerifyCheckoutSession.(user, "cs_test_123")
    end
    assert_equal "Checkout session has no subscription", error.message
  end

  test "raises ArgumentError for unknown price ID" do
    user = create(:user)
    user.data.update!(stripe_customer_id: "cus_123")

    stripe_session = mock
    stripe_session.stubs(:metadata).returns(nil)
    stripe_session.stubs(:customer).returns("cus_123")
    stripe_session.stubs(:status).returns("complete")
    stripe_session.stubs(:subscription).returns("sub_123")

    # Minimal subscription mock — only stub what's needed before the error
    price = mock
    price.stubs(:id).returns("price_unknown_xyz")
    item = mock
    item.stubs(:price).returns(price)
    items_data = mock
    items_data.stubs(:data).returns([item])
    stripe_subscription = mock
    stripe_subscription.stubs(:items).returns(items_data)

    ::Stripe::Checkout::Session.expects(:retrieve).with("cs_test_123").returns(stripe_session)
    ::Stripe::Subscription.expects(:retrieve).with("sub_123").returns(stripe_subscription)

    error = assert_raises(ArgumentError) do
      Stripe::VerifyCheckoutSession.(user, "cs_test_123")
    end
    assert_match(/Unknown Stripe price ID/, error.message)
  end

  test "verifies via metadata user_id and persists stripe_customer_id when user has none" do
    user = create(:user)
    assert_nil user.data.stripe_customer_id

    stripe_session = mock_stripe_session(user_id: user.id, customer: "cus_new")
    stripe_subscription = mock_stripe_subscription(price_id: Jiki.config.stripe_premium_monthly_price_id)

    ::Stripe::Checkout::Session.expects(:retrieve).with("cs_test_123").returns(stripe_session)
    ::Stripe::Subscription.expects(:retrieve).with("sub_123").returns(stripe_subscription)

    result = Stripe::VerifyCheckoutSession.(user, "cs_test_123")

    assert result[:success]
    user.data.reload
    assert_equal "cus_new", user.data.stripe_customer_id
    assert_equal "sub_123", user.data.stripe_subscription_id
  end

  test "raises SecurityError when metadata user_id does not match current user" do
    user = create(:user)
    other_user = create(:user)

    stripe_session = mock
    stripe_session.stubs(:metadata).returns({ user_id: other_user.id.to_s })

    ::Stripe::Checkout::Session.expects(:retrieve).with("cs_test_123").returns(stripe_session)

    assert_raises(SecurityError) do
      Stripe::VerifyCheckoutSession.(user, "cs_test_123")
    end
  end

  test "handles incomplete subscription for async payments" do
    user = create(:user)
    user.data.update!(stripe_customer_id: "cus_123", membership_type: "standard")

    stripe_session = mock_stripe_session(payment_status: "unpaid")
    stripe_subscription = mock_stripe_subscription(
      status: "incomplete",
      price_id: Jiki.config.stripe_premium_monthly_price_id
    )

    ::Stripe::Checkout::Session.expects(:retrieve).with("cs_test_123").returns(stripe_session)
    ::Stripe::Subscription.expects(:retrieve).with("sub_123").returns(stripe_subscription)

    result = Stripe::VerifyCheckoutSession.(user, "cs_test_123")

    assert result[:success]
    assert_equal "monthly", result[:interval]
    assert_equal "unpaid", result[:payment_status]
    assert_equal "incomplete", result[:subscription_status]

    user.data.reload
    assert_equal "standard", user.data.membership_type
    assert_equal "incomplete", user.data.subscription_status
  end

  private
  def mock_stripe_session(payment_status: "paid", user_id: nil, customer: "cus_123")
    session = mock
    session.stubs(:metadata).returns(user_id ? { user_id: user_id.to_s } : nil)
    session.stubs(:customer).returns(customer)
    session.stubs(:status).returns("complete")
    session.stubs(:subscription).returns("sub_123")
    session.stubs(:payment_status).returns(payment_status)
    session
  end

  def mock_stripe_subscription(price_id:, status: "active")
    subscription = mock
    subscription.stubs(:id).returns("sub_123")
    subscription.stubs(:status).returns(status)

    price = mock
    price.stubs(:id).returns(price_id)
    item = mock
    item.stubs(:price).returns(price)
    item.stubs(:current_period_end).returns(1.month.from_now.to_i)
    items_data = mock
    items_data.stubs(:data).returns([item])
    subscription.stubs(:items).returns(items_data)

    subscription
  end
end
