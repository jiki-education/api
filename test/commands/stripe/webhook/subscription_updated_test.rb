require "test_helper"

class Stripe::Webhook::SubscriptionUpdatedTest < ActiveSupport::TestCase
  # Helper to add items mock with current_period_end to subscription
  def add_items_mock_to_subscription(subscription, period_end, price_id = nil)
    item = mock
    item.stubs(:current_period_end).returns(period_end.to_i) if period_end
    item.stubs(:price).returns(mock(id: price_id)) if price_id

    items = mock
    items.stubs(:data).returns([item])

    subscription.stubs(:items).returns(items)
  end

  setup do
    @user = create(:user)
    @period_end = 1.month.from_now
    @user.data.update!(
      stripe_subscription_id: "sub_123",
      membership_type: "premium",
      subscription_status: "active",
      subscription_valid_until: @period_end,
      subscriptions: [{
        stripe_subscription_id: "sub_123",
        tier: "premium",
        started_at: 1.month.ago.iso8601,
        ended_at: nil,
        end_reason: nil,
        payment_failed_at: nil
      }]
    )
  end

  test "handles user not found" do
    subscription = mock
    subscription.stubs(:id).returns("sub_nonexistent")

    event_data = mock
    event_data.stubs(:object).returns(subscription)

    event = mock
    event.stubs(:data).returns(event_data)

    assert_nothing_raised do
      Stripe::Webhook::SubscriptionUpdated.(event)
    end
  end

  test "updates subscription status to active" do
    @user.data.update!(
      stripe_subscription_status: "past_due",
      subscription_status: "payment_failed"
    )

    subscription = mock
    subscription.stubs(:id).returns("sub_123")
    subscription.stubs(:status).returns("active")
    subscription.stubs(:cancel_at_period_end).returns(false)
    add_items_mock_to_subscription(subscription, @period_end)

    event_data = mock
    event_data.stubs(:object).returns(subscription)
    event_data.stubs(:previous_attributes).returns({})

    event = mock
    event.stubs(:data).returns(event_data)

    Stripe::Webhook::SubscriptionUpdated.(event)

    @user.data.reload
    assert_equal "active", @user.data.stripe_subscription_status
    assert_equal "active", @user.data.subscription_status
  end

  test "updates subscription status to past_due and records payment_failed_at in array" do
    subscription = mock
    subscription.stubs(:id).returns("sub_123")
    subscription.stubs(:status).returns("past_due")
    add_items_mock_to_subscription(subscription, @period_end)
    subscription.stubs(:cancel_at_period_end).returns(false)

    event_data = mock
    event_data.stubs(:object).returns(subscription)
    event_data.stubs(:previous_attributes).returns({})

    event = mock
    event.stubs(:data).returns(event_data)

    Stripe::Webhook::SubscriptionUpdated.(event)

    @user.data.reload
    assert_equal "past_due", @user.data.stripe_subscription_status
    assert_equal "payment_failed", @user.data.subscription_status

    # Check payment_failed_at in subscriptions array
    sub_entry = @user.data.subscriptions.first
    refute_nil sub_entry["payment_failed_at"]
  end

  test "does not overwrite payment_failed_at in array if already set" do
    original_failed_at = 2.days.ago
    @user.data.update!(
      subscriptions: [{
        stripe_subscription_id: "sub_123",
        tier: "premium",
        started_at: 1.month.ago.iso8601,
        ended_at: nil,
        end_reason: nil,
        payment_failed_at: original_failed_at.iso8601
      }]
    )

    subscription = mock
    subscription.stubs(:id).returns("sub_123")
    subscription.stubs(:status).returns("past_due")
    add_items_mock_to_subscription(subscription, @period_end)
    subscription.stubs(:cancel_at_period_end).returns(false)

    event_data = mock
    event_data.stubs(:object).returns(subscription)
    event_data.stubs(:previous_attributes).returns({})

    event = mock
    event.stubs(:data).returns(event_data)

    Stripe::Webhook::SubscriptionUpdated.(event)

    @user.data.reload
    sub_entry = @user.data.subscriptions.first
    assert_in_delta original_failed_at.to_i, Time.parse(sub_entry["payment_failed_at"]).to_i, 1
  end

  test "updates subscription status to canceled" do
    subscription = mock
    subscription.stubs(:id).returns("sub_123")
    subscription.stubs(:status).returns("canceled")
    add_items_mock_to_subscription(subscription, @period_end)
    subscription.stubs(:cancel_at_period_end).returns(false)

    event_data = mock
    event_data.stubs(:object).returns(subscription)
    event_data.stubs(:previous_attributes).returns({})

    event = mock
    event.stubs(:data).returns(event_data)

    Stripe::Webhook::SubscriptionUpdated.(event)

    @user.data.reload
    assert_equal "canceled", @user.data.stripe_subscription_status
  end

  test "downgrades to standard tier on unpaid status" do
    @user.data.update!(membership_type: "max")

    subscription = mock
    subscription.stubs(:id).returns("sub_123")
    subscription.stubs(:status).returns("unpaid")
    add_items_mock_to_subscription(subscription, @period_end)
    subscription.stubs(:cancel_at_period_end).returns(false)

    event_data = mock
    event_data.stubs(:object).returns(subscription)
    event_data.stubs(:previous_attributes).returns({})

    event = mock
    event.stubs(:data).returns(event_data)

    Stripe::Webhook::SubscriptionUpdated.(event)

    @user.data.reload
    assert_equal "standard", @user.data.membership_type
    assert_equal "unpaid", @user.data.stripe_subscription_status
    assert_equal "payment_failed", @user.data.subscription_status
  end

  test "handles trialing status as active" do
    subscription = mock
    subscription.stubs(:id).returns("sub_123")
    subscription.stubs(:status).returns("trialing")
    add_items_mock_to_subscription(subscription, @period_end)
    subscription.stubs(:cancel_at_period_end).returns(false)

    event_data = mock
    event_data.stubs(:object).returns(subscription)
    event_data.stubs(:previous_attributes).returns({})

    event = mock
    event.stubs(:data).returns(event_data)

    Stripe::Webhook::SubscriptionUpdated.(event)

    @user.data.reload
    assert_equal "trialing", @user.data.stripe_subscription_status
    assert_equal "active", @user.data.subscription_status
  end

  test "updates subscription_valid_until" do
    new_period_end = 2.months.from_now

    subscription = mock
    subscription.stubs(:id).returns("sub_123")
    subscription.stubs(:status).returns("active")
    subscription.stubs(:cancel_at_period_end).returns(false)
    add_items_mock_to_subscription(subscription, new_period_end)

    event_data = mock
    event_data.stubs(:object).returns(subscription)
    event_data.stubs(:previous_attributes).returns({})

    event = mock
    event.stubs(:data).returns(event_data)

    Stripe::Webhook::SubscriptionUpdated.(event)

    @user.data.reload
    assert_in_delta new_period_end.to_i, @user.data.subscription_valid_until.to_i, 1
  end

  test "handles tier change from premium to max" do
    @user.data.update!(membership_type: "premium")

    price = mock
    price.stubs(:id).returns(Jiki.config.stripe_max_price_id)

    item = mock
    item.stubs(:price).returns(price)
    item.stubs(:current_period_end).returns(@period_end.to_i)

    items_data = mock
    items_data.stubs(:first).returns(item)

    items = mock
    items.stubs(:data).returns(items_data)

    subscription = mock
    subscription.stubs(:id).returns("sub_123")
    subscription.stubs(:status).returns("active")
    subscription.stubs(:cancel_at_period_end).returns(false)
    subscription.stubs(:items).returns(items)

    event_data = mock
    event_data.stubs(:object).returns(subscription)
    event_data.stubs(:previous_attributes).returns({ 'items' => true })

    event = mock
    event.stubs(:data).returns(event_data)

    Stripe::Webhook::SubscriptionUpdated.(event)

    @user.data.reload
    assert_equal "max", @user.data.membership_type

    # Check subscriptions array updated
    assert_equal 2, @user.data.subscriptions.length
    old_sub = @user.data.subscriptions.first
    new_sub = @user.data.subscriptions.last

    # Old subscription should be closed with upgraded end_reason
    assert_equal "premium", old_sub["tier"]
    refute_nil old_sub["ended_at"]
    assert_equal "upgraded", old_sub["end_reason"]

    # New subscription should be open
    assert_equal "max", new_sub["tier"]
    assert_nil new_sub["ended_at"]
  end

  test "handles tier change from max to premium" do
    @user.data.update!(
      membership_type: "max",
      subscriptions: [{
        stripe_subscription_id: "sub_123",
        tier: "max",
        started_at: 1.month.ago.iso8601,
        ended_at: nil,
        end_reason: nil,
        payment_failed_at: nil
      }]
    )

    price = mock
    price.stubs(:id).returns(Jiki.config.stripe_premium_price_id)

    item = mock
    item.stubs(:price).returns(price)
    item.stubs(:current_period_end).returns(@period_end.to_i)

    items_data = mock
    items_data.stubs(:first).returns(item)

    items = mock
    items.stubs(:data).returns(items_data)

    subscription = mock
    subscription.stubs(:id).returns("sub_123")
    subscription.stubs(:status).returns("active")
    subscription.stubs(:cancel_at_period_end).returns(false)
    subscription.stubs(:items).returns(items)

    event_data = mock
    event_data.stubs(:object).returns(subscription)
    event_data.stubs(:previous_attributes).returns({ 'items' => true })

    event = mock
    event.stubs(:data).returns(event_data)

    Stripe::Webhook::SubscriptionUpdated.(event)

    @user.data.reload
    assert_equal "premium", @user.data.membership_type

    # Check subscriptions array updated
    assert_equal 2, @user.data.subscriptions.length
    old_sub = @user.data.subscriptions.first
    new_sub = @user.data.subscriptions.last

    # Old subscription should be closed with downgraded end_reason
    assert_equal "max", old_sub["tier"]
    assert_equal "downgraded", old_sub["end_reason"]

    # New subscription should be open
    assert_equal "premium", new_sub["tier"]
    assert_nil new_sub["ended_at"]
  end

  test "does not change tier if price did not change" do
    @user.data.update!(membership_type: "premium")

    subscription = mock
    subscription.stubs(:id).returns("sub_123")
    subscription.stubs(:status).returns("active")
    add_items_mock_to_subscription(subscription, @period_end)
    subscription.stubs(:cancel_at_period_end).returns(false)

    event_data = mock
    event_data.stubs(:object).returns(subscription)
    event_data.stubs(:previous_attributes).returns({})

    event = mock
    event.stubs(:data).returns(event_data)

    Stripe::Webhook::SubscriptionUpdated.(event)

    @user.data.reload
    assert_equal "premium", @user.data.membership_type
    # Should still have only 1 subscription entry
    assert_equal 1, @user.data.subscriptions.length
  end

  test "sets status to cancelling when cancel_at_period_end is true" do
    subscription = mock
    subscription.stubs(:id).returns("sub_123")
    subscription.stubs(:status).returns("active")
    add_items_mock_to_subscription(subscription, @period_end)
    subscription.stubs(:cancel_at_period_end).returns(true)

    event_data = mock
    event_data.stubs(:object).returns(subscription)
    event_data.stubs(:previous_attributes).returns({})

    event = mock
    event.stubs(:data).returns(event_data)

    Stripe::Webhook::SubscriptionUpdated.(event)

    @user.data.reload
    assert_equal "cancelling", @user.data.subscription_status
  end

  test "undoes cancellation when cancel_at_period_end changes to false" do
    @user.data.update!(subscription_status: "cancelling")

    subscription = mock
    subscription.stubs(:id).returns("sub_123")
    subscription.stubs(:status).returns("active")
    add_items_mock_to_subscription(subscription, @period_end)
    subscription.stubs(:cancel_at_period_end).returns(false)

    event_data = mock
    event_data.stubs(:object).returns(subscription)
    event_data.stubs(:previous_attributes).returns({})

    event = mock
    event.stubs(:data).returns(event_data)

    Stripe::Webhook::SubscriptionUpdated.(event)

    @user.data.reload
    assert_equal "active", @user.data.subscription_status
  end

  test "raises ArgumentError for unknown price ID on tier change" do
    @user.data.update!(membership_type: "premium")

    price = mock
    price.stubs(:id).returns("price_unknown_xyz")

    item = mock
    item.stubs(:price).returns(price)

    items_data = mock
    items_data.stubs(:first).returns(item)

    items = mock
    items.stubs(:data).returns(items_data)

    subscription = mock
    subscription.stubs(:id).returns("sub_123")
    subscription.stubs(:items).returns(items)

    event_data = mock
    event_data.stubs(:object).returns(subscription)
    event_data.stubs(:previous_attributes).returns({ 'items' => true })

    event = mock
    event.stubs(:data).returns(event_data)

    error = assert_raises(ArgumentError) do
      Stripe::Webhook::SubscriptionUpdated.(event)
    end

    assert_match(/Unknown Stripe price ID/, error.message)
    assert_match(/price_unknown_xyz/, error.message)
  end

  test "is idempotent - does not duplicate new tier entry on retry" do
    # Simulate webhook already processed once - user has both old and new subscription entries
    @user.data.update!(
      membership_type: "max",
      subscriptions: [
        {
          stripe_subscription_id: "sub_123",
          tier: "premium",
          started_at: 2.months.ago.iso8601,
          ended_at: 1.hour.ago.iso8601,
          end_reason: "upgraded",
          payment_failed_at: nil
        },
        {
          stripe_subscription_id: "sub_123",
          tier: "max",
          started_at: 1.hour.ago.iso8601,
          ended_at: nil,
          end_reason: nil,
          payment_failed_at: nil
        }
      ]
    )

    price = mock
    price.stubs(:id).returns(Jiki.config.stripe_max_price_id)

    item = mock
    item.stubs(:price).returns(price)
    item.stubs(:current_period_end).returns(@period_end.to_i)

    items_data = mock
    items_data.stubs(:first).returns(item)

    items = mock
    items.stubs(:data).returns(items_data)

    subscription = mock
    subscription.stubs(:id).returns("sub_123")
    subscription.stubs(:status).returns("active")
    subscription.stubs(:cancel_at_period_end).returns(false)
    subscription.stubs(:items).returns(items)

    event_data = mock
    event_data.stubs(:object).returns(subscription)
    event_data.stubs(:previous_attributes).returns({ 'items' => true })

    event = mock
    event.stubs(:data).returns(event_data)

    # Call webhook again (simulating retry)
    Stripe::Webhook::SubscriptionUpdated.(event)

    @user.data.reload
    # Should still have exactly 2 entries (not 3)
    assert_equal 2, @user.data.subscriptions.length

    # Verify the max tier entry exists and is still open
    max_sub = @user.data.subscriptions.find { |s| s["tier"] == "max" }
    refute_nil max_sub
    assert_nil max_sub["ended_at"]
  end
end
