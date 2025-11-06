require "test_helper"

class Stripe::VerifyCheckoutSessionTest < ActiveSupport::TestCase
  test "verifies checkout session and updates user subscription data for premium" do
    user = create(:user)
    user.data.update!(stripe_customer_id: "cus_123")
    session_id = "cs_test_123"

    # Mock Stripe responses
    stripe_session = mock
    stripe_session.stubs(:customer).returns("cus_123")
    stripe_session.stubs(:status).returns("complete")
    stripe_session.stubs(:subscription).returns("sub_123")

    stripe_subscription = mock
    stripe_subscription.stubs(:id).returns("sub_123")
    stripe_subscription.stubs(:status).returns("active")

    # Mock subscription items with premium price
    price = mock
    price.stubs(:id).returns(Jiki.config.stripe_premium_price_id)
    item = mock
    item.stubs(:price).returns(price)
    item.stubs(:current_period_end).returns(1.month.from_now.to_i)
    items_data = mock
    items_data.stubs(:data).returns([item])
    stripe_subscription.stubs(:items).returns(items_data)

    ::Stripe::Checkout::Session.expects(:retrieve).with(session_id).returns(stripe_session)
    ::Stripe::Subscription.expects(:retrieve).with("sub_123").returns(stripe_subscription)

    result = Stripe::VerifyCheckoutSession.(user, session_id)

    assert result[:success]
    assert_equal "premium", result[:tier]

    # Verify user data was updated
    user.data.reload
    assert_equal "premium", user.data.membership_type
    assert_equal "sub_123", user.data.stripe_subscription_id
    assert_equal "active", user.data.stripe_subscription_status
    refute_nil user.data.subscription_current_period_end
    assert_nil user.data.payment_failed_at
  end

  test "verifies checkout session and updates user subscription data for max" do
    user = create(:user)
    user.data.update!(stripe_customer_id: "cus_123")
    session_id = "cs_test_123"

    # Mock Stripe responses
    stripe_session = mock
    stripe_session.stubs(:customer).returns("cus_123")
    stripe_session.stubs(:status).returns("complete")
    stripe_session.stubs(:subscription).returns("sub_123")

    stripe_subscription = mock
    stripe_subscription.stubs(:id).returns("sub_123")
    stripe_subscription.stubs(:status).returns("active")

    # Mock subscription items with max price
    price = mock
    price.stubs(:id).returns(Jiki.config.stripe_max_price_id)
    item = mock
    item.stubs(:price).returns(price)
    item.stubs(:current_period_end).returns(1.month.from_now.to_i)
    items_data = mock
    items_data.stubs(:data).returns([item])
    stripe_subscription.stubs(:items).returns(items_data)

    ::Stripe::Checkout::Session.expects(:retrieve).with(session_id).returns(stripe_session)
    ::Stripe::Subscription.expects(:retrieve).with("sub_123").returns(stripe_subscription)

    result = Stripe::VerifyCheckoutSession.(user, session_id)

    assert result[:success]
    assert_equal "max", result[:tier]

    user.data.reload
    assert_equal "max", user.data.membership_type
  end

  test "raises SecurityError when session customer does not match user" do
    user = create(:user)
    user.data.update!(stripe_customer_id: "cus_123")
    session_id = "cs_test_123"

    stripe_session = mock
    stripe_session.stubs(:customer).returns("cus_different")

    ::Stripe::Checkout::Session.expects(:retrieve).with(session_id).returns(stripe_session)

    error = assert_raises(SecurityError) do
      Stripe::VerifyCheckoutSession.(user, session_id)
    end

    assert_equal "Checkout session does not belong to current user", error.message
  end

  test "raises ArgumentError when session is not complete" do
    user = create(:user)
    user.data.update!(stripe_customer_id: "cus_123")
    session_id = "cs_test_123"

    stripe_session = mock
    stripe_session.stubs(:customer).returns("cus_123")
    stripe_session.stubs(:status).returns("open")

    ::Stripe::Checkout::Session.expects(:retrieve).with(session_id).returns(stripe_session)

    error = assert_raises(ArgumentError) do
      Stripe::VerifyCheckoutSession.(user, session_id)
    end

    assert_match(/not complete/, error.message)
  end

  test "raises ArgumentError when session has no subscription" do
    user = create(:user)
    user.data.update!(stripe_customer_id: "cus_123")
    session_id = "cs_test_123"

    stripe_session = mock
    stripe_session.stubs(:customer).returns("cus_123")
    stripe_session.stubs(:status).returns("complete")
    stripe_session.stubs(:subscription).returns(nil)

    ::Stripe::Checkout::Session.expects(:retrieve).with(session_id).returns(stripe_session)

    error = assert_raises(ArgumentError) do
      Stripe::VerifyCheckoutSession.(user, session_id)
    end

    assert_equal "Checkout session has no subscription", error.message
  end

  test "raises ArgumentError for unknown price ID" do
    user = create(:user)
    user.data.update!(stripe_customer_id: "cus_123")
    session_id = "cs_test_123"

    # Mock Stripe responses with unknown price ID
    stripe_session = mock
    stripe_session.stubs(:customer).returns("cus_123")
    stripe_session.stubs(:status).returns("complete")
    stripe_session.stubs(:subscription).returns("sub_123")

    # Mock subscription items with UNKNOWN price ID
    price = mock
    price.stubs(:id).returns("price_unknown_xyz")
    item = mock
    item.stubs(:price).returns(price)
    # NOTE: Don't stub current_period_end since we raise error before accessing it
    items_data = mock
    items_data.stubs(:data).returns([item])

    stripe_subscription = mock
    stripe_subscription.stubs(:items).returns(items_data)

    ::Stripe::Checkout::Session.expects(:retrieve).with(session_id).returns(stripe_session)
    ::Stripe::Subscription.expects(:retrieve).with("sub_123").returns(stripe_subscription)

    error = assert_raises(ArgumentError) do
      Stripe::VerifyCheckoutSession.(user, session_id)
    end

    assert_match(/Unknown Stripe price ID/, error.message)
    assert_match(/price_unknown_xyz/, error.message)
  end
end
