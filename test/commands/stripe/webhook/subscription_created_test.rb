require "test_helper"

class Stripe::Webhook::SubscriptionCreatedTest < ActiveSupport::TestCase
  test "creates premium subscription for user" do
    user = create(:user)
    user.data.update!(stripe_customer_id: "cus_123")

    period_end = 1.month.from_now

    price = mock
    price.stubs(:id).returns(Jiki.config.stripe_premium_price_id)

    item = mock
    item.stubs(:price).returns(price)
    item.stubs(:current_period_end).returns(period_end.to_i)

    items = mock
    items.stubs(:data).returns([item])

    subscription = mock
    subscription.stubs(:customer).returns("cus_123")
    subscription.stubs(:id).returns("sub_123")
    subscription.stubs(:status).returns("active")
    subscription.stubs(:items).returns(items)

    event = mock
    event.stubs(:data).returns(mock(object: subscription))

    Stripe::Webhook::SubscriptionCreated.(event)

    user.data.reload
    assert_equal "premium", user.data.membership_type
    assert_equal "sub_123", user.data.stripe_subscription_id
    assert_equal "active", user.data.stripe_subscription_status
    assert_equal "active", user.data.subscription_status
    assert_in_delta period_end.to_i, user.data.subscription_valid_until.to_i, 1

    # Check subscriptions array
    assert_equal 1, user.data.subscriptions.length
    sub_entry = user.data.subscriptions.first
    assert_equal "sub_123", sub_entry["stripe_subscription_id"]
    assert_equal "premium", sub_entry["tier"]
    assert_nil sub_entry["ended_at"]
    assert_nil sub_entry["end_reason"]
    assert_nil sub_entry["payment_failed_at"]
  end

  test "creates max subscription for user" do
    user = create(:user)
    user.data.update!(stripe_customer_id: "cus_123")

    price = mock
    price.stubs(:id).returns(Jiki.config.stripe_max_price_id)

    item = mock
    item.stubs(:price).returns(price)
    item.stubs(:current_period_end).returns(1.month.from_now.to_i)

    items = mock
    items.stubs(:data).returns([item])

    subscription = mock
    subscription.stubs(:customer).returns("cus_123")
    subscription.stubs(:id).returns("sub_123")
    subscription.stubs(:status).returns("active")
    subscription.stubs(:items).returns(items)

    event = mock
    event.stubs(:data).returns(mock(object: subscription))

    Stripe::Webhook::SubscriptionCreated.(event)

    user.data.reload
    assert_equal "max", user.data.membership_type
    assert_equal "active", user.data.subscription_status
  end

  test "creates incomplete subscription for user" do
    user = create(:user)
    user.data.update!(stripe_customer_id: "cus_123")

    price = mock
    price.stubs(:id).returns(Jiki.config.stripe_premium_price_id)

    item = mock
    item.stubs(:price).returns(price)
    item.stubs(:current_period_end).returns(1.day.from_now.to_i)

    items = mock
    items.stubs(:data).returns([item])

    subscription = mock
    subscription.stubs(:customer).returns("cus_123")
    subscription.stubs(:id).returns("sub_123")
    subscription.stubs(:status).returns("incomplete")
    subscription.stubs(:items).returns(items)

    event = mock
    event.stubs(:data).returns(mock(object: subscription))

    Stripe::Webhook::SubscriptionCreated.(event)

    user.data.reload
    assert_equal "standard", user.data.membership_type # Stays standard until payment completes
    assert_equal "incomplete", user.data.subscription_status
    assert_equal "sub_123", user.data.stripe_subscription_id

    # Should still create subscriptions array entry
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
    # NOTE: subscription.id is not stubbed because we error before using it
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
end
