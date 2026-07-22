require "test_helper"

class Stripe::Webhook::SubscriptionCreatedTest < ActiveSupport::TestCase
  test "creates monthly subscription for user" do
    user = create(:user)
    user.data.update!(stripe_customer_id: "cus_123")

    period_end = 1.month.from_now
    event = mock_event(price_id: Jiki.config.stripe_premium_monthly_price_id, period_end:)

    Stripe::Webhook::SubscriptionCreated.(event)

    user.data.reload
    assert user.premium?
    assert_equal "monthly", user.data.subscription_interval
    assert_equal "sub_123", user.data.stripe_subscription_id
    assert_equal "active", user.data.stripe_subscription_status
    assert_equal "active", user.data.subscription_status
    assert_in_delta period_end.to_i, user.data.subscription_valid_until.to_i, 1

    assert_equal 1, user.data.subscriptions.length
    sub_entry = user.data.subscriptions.first
    assert_equal "sub_123", sub_entry["stripe_subscription_id"]
    assert_equal "premium", sub_entry["tier"]
    assert_equal "monthly", sub_entry["interval"]
    assert_nil sub_entry["ended_at"]
  end

  test "creates annual subscription for user" do
    user = create(:user)
    user.data.update!(stripe_customer_id: "cus_123")

    event = mock_event(price_id: Jiki.config.stripe_premium_annual_price_id)

    Stripe::Webhook::SubscriptionCreated.(event)

    user.data.reload
    assert user.premium?
    assert_equal "annual", user.data.subscription_interval
    assert_equal "active", user.data.subscription_status
  end

  test "creates incomplete subscription for user" do
    user = create(:user)
    user.data.update!(stripe_customer_id: "cus_123")

    event = mock_event(
      price_id: Jiki.config.stripe_premium_monthly_price_id,
      status: "incomplete"
    )

    Stripe::Webhook::SubscriptionCreated.(event)

    user.data.reload
    refute user.premium?
    assert_equal "incomplete", user.data.subscription_status
    assert_equal "sub_123", user.data.stripe_subscription_id

    assert_equal 1, user.data.subscriptions.length
    assert_equal "premium", user.data.subscriptions.first["tier"]
  end

  test "raises ArgumentError for unknown price ID" do
    user = create(:user)
    user.data.update!(stripe_customer_id: "cus_123")

    price = mock
    price.stubs(:id).returns("price_unknown_xyz")
    item = mock
    item.stubs(:price).returns(price)
    items = mock
    items.stubs(:data).returns([item])

    subscription = mock
    subscription.stubs(:customer).returns("cus_123")
    subscription.stubs(:status).returns("active")
    subscription.stubs(:items).returns(items)

    event = mock
    event.stubs(:data).returns(mock(object: subscription))

    error = assert_raises(ArgumentError) do
      Stripe::Webhook::SubscriptionCreated.(event)
    end

    assert_match(/Unknown Stripe price ID/, error.message)
    assert_match(/price_unknown_xyz/, error.message)
  end

  test "skips expired incomplete subscriptions" do
    user = create(:user)
    user.data.update!(stripe_customer_id: "cus_123")

    subscription = mock
    subscription.stubs(:status).returns("incomplete_expired")

    event = mock
    event.stubs(:data).returns(mock(object: subscription))

    Stripe::Webhook::SubscriptionCreated.(event)

    user.data.reload
    refute user.premium?
    assert_equal "never_subscribed", user.data.subscription_status
  end

  test "resolves user via subscription metadata when customer is not linked" do
    # The user has no stripe_customer_id - e.g. checkout.session.completed was
    # dropped or arrived after this event, so it never linked the customer.
    user = create(:user)

    event = mock_event(
      price_id: Jiki.config.stripe_premium_monthly_price_id,
      metadata: { user_id: user.id.to_s }
    )

    Stripe::Webhook::SubscriptionCreated.(event)

    user.data.reload
    assert user.premium?
    assert_equal "active", user.data.subscription_status
    # The customer id is backfilled so future webhooks can find the user by it.
    assert_equal "cus_123", user.data.stripe_customer_id
  end

  test "prefers customer lookup over metadata" do
    customer_user = create(:user)
    customer_user.data.update!(stripe_customer_id: "cus_123")
    metadata_user = create(:user)

    # metadata is deliberately not stubbed: the customer lookup must win and
    # short-circuit before metadata is ever read.
    event = mock_event(price_id: Jiki.config.stripe_premium_monthly_price_id)

    Stripe::Webhook::SubscriptionCreated.(event)

    assert customer_user.data.reload.premium?
    refute metadata_user.data.reload.premium?
  end

  test "does nothing when user cannot be found by customer or metadata" do
    subscription = mock
    subscription.stubs(:status).returns("active")
    subscription.stubs(:customer).returns("cus_unknown")
    subscription.stubs(:metadata).returns({})

    event = mock
    event.stubs(:data).returns(mock(object: subscription))

    # The subscription must be dropped, not synced to some arbitrary user.
    Stripe::SyncSubscriptionToUser.expects(:call).never

    Stripe::Webhook::SubscriptionCreated.(event)
  end

  private
  def mock_event(price_id:, status: "active", period_end: 1.month.from_now, customer: "cus_123", metadata: nil)
    price = mock
    price.stubs(:id).returns(price_id)

    item = mock
    item.stubs(:price).returns(price)
    item.stubs(:current_period_end).returns(period_end.to_i)

    items = mock
    items.stubs(:data).returns([item])

    subscription = mock
    subscription.stubs(:customer).returns(customer)
    subscription.stubs(:id).returns("sub_123")
    subscription.stubs(:status).returns(status)
    subscription.stubs(:items).returns(items)
    # Only stub metadata when the test exercises the fallback; strict Mocha
    # errors on stubs that go unused when the customer lookup short-circuits.
    subscription.stubs(:metadata).returns(metadata) unless metadata.nil?

    event = mock
    event.stubs(:data).returns(mock(object: subscription))
    event
  end
end
