require "test_helper"

class Stripe::Webhook::SubscriptionCreatedTest < ActiveSupport::TestCase
  test "creates premium subscription for user" do
    user = create(:user)
    user.data.update!(stripe_customer_id: "cus_123")

    price = mock
    price.stubs(:id).returns(Jiki.config.stripe_premium_price_id)

    item = mock
    item.stubs(:price).returns(price)

    items = mock
    items.stubs(:data).returns([item])

    subscription = mock
    subscription.stubs(:customer).returns("cus_123")
    subscription.stubs(:id).returns("sub_123")
    subscription.stubs(:status).returns("active")
    subscription.stubs(:current_period_end).returns(1.month.from_now.to_i)
    subscription.stubs(:items).returns(items)

    event = mock
    event.stubs(:data).returns(mock(object: subscription))

    Stripe::Webhook::SubscriptionCreated.(event)

    user.data.reload
    assert_equal "premium", user.data.membership_type
    assert_equal "sub_123", user.data.stripe_subscription_id
    assert_equal "active", user.data.stripe_subscription_status
    assert_nil user.data.payment_failed_at
  end

  test "creates max subscription for user" do
    user = create(:user)
    user.data.update!(stripe_customer_id: "cus_123")

    price = mock
    price.stubs(:id).returns(Jiki.config.stripe_max_price_id)

    item = mock
    item.stubs(:price).returns(price)

    items = mock
    items.stubs(:data).returns([item])

    subscription = mock
    subscription.stubs(:customer).returns("cus_123")
    subscription.stubs(:id).returns("sub_123")
    subscription.stubs(:status).returns("active")
    subscription.stubs(:current_period_end).returns(1.month.from_now.to_i)
    subscription.stubs(:items).returns(items)

    event = mock
    event.stubs(:data).returns(mock(object: subscription))

    Stripe::Webhook::SubscriptionCreated.(event)

    user.data.reload
    assert_equal "max", user.data.membership_type
  end
end
