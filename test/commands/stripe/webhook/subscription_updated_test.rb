require "test_helper"

class Stripe::Webhook::SubscriptionUpdatedTest < ActiveSupport::TestCase
  setup do
    @user = create(:user)
    @user.data.update!(
      stripe_subscription_id: "sub_123",
      membership_type: "premium"
    )
  end

  test "handles user not found" do
    # Create minimal event mock - handler returns early so items aren't accessed
    subscription = mock
    subscription.stubs(:id).returns("sub_nonexistent")

    event_data = mock
    event_data.stubs(:object).returns(subscription)

    event = mock
    event.stubs(:data).returns(event_data)

    # Should not raise error, just log
    assert_nothing_raised do
      Stripe::Webhook::SubscriptionUpdated.(event)
    end
  end

  test "updates subscription status to active and clears payment_failed_at" do
    @user.data.update!(
      stripe_subscription_status: "past_due",
      payment_failed_at: 1.day.ago
    )

    event = create_event(
      subscription_id: "sub_123",
      status: "active"
    )

    Stripe::Webhook::SubscriptionUpdated.(event)

    @user.data.reload
    assert_equal "active", @user.data.stripe_subscription_status
    assert_nil @user.data.payment_failed_at
  end

  test "updates subscription status to past_due and sets payment_failed_at" do
    @user.data.update!(payment_failed_at: nil)

    event = create_event(
      subscription_id: "sub_123",
      status: "past_due"
    )

    Stripe::Webhook::SubscriptionUpdated.(event)

    @user.data.reload
    assert_equal "past_due", @user.data.stripe_subscription_status
    refute_nil @user.data.payment_failed_at
  end

  test "does not overwrite payment_failed_at if already set" do
    original_failed_at = 2.days.ago
    @user.data.update!(payment_failed_at: original_failed_at)

    event = create_event(
      subscription_id: "sub_123",
      status: "past_due"
    )

    Stripe::Webhook::SubscriptionUpdated.(event)

    @user.data.reload
    assert_equal "past_due", @user.data.stripe_subscription_status
    assert_in_delta original_failed_at.to_i, @user.data.payment_failed_at.to_i, 1
  end

  test "updates subscription status to canceled" do
    event = create_event(
      subscription_id: "sub_123",
      status: "canceled"
    )

    Stripe::Webhook::SubscriptionUpdated.(event)

    @user.data.reload
    assert_equal "canceled", @user.data.stripe_subscription_status
  end

  test "downgrades to standard tier on unpaid status" do
    @user.data.update!(membership_type: "max")

    event = create_event(
      subscription_id: "sub_123",
      status: "unpaid"
    )

    Stripe::Webhook::SubscriptionUpdated.(event)

    @user.data.reload
    assert_equal "standard", @user.data.membership_type
    assert_equal "unpaid", @user.data.stripe_subscription_status
  end

  test "handles other statuses (trialing, incomplete, etc)" do
    event = create_event(
      subscription_id: "sub_123",
      status: "trialing"
    )

    Stripe::Webhook::SubscriptionUpdated.(event)

    @user.data.reload
    assert_equal "trialing", @user.data.stripe_subscription_status
  end

  test "updates current_period_end" do
    new_period_end = 1.month.from_now.to_i

    event = create_event(
      subscription_id: "sub_123",
      status: "active",
      current_period_end: new_period_end
    )

    Stripe::Webhook::SubscriptionUpdated.(event)

    @user.data.reload
    assert_in_delta new_period_end, @user.data.subscription_current_period_end.to_i, 1
  end

  test "handles tier change from premium to max" do
    @user.data.update!(membership_type: "premium")

    event = create_event(
      subscription_id: "sub_123",
      status: "active",
      price_id: Jiki.config.stripe_max_price_id,
      with_items_change: true
    )

    Stripe::Webhook::SubscriptionUpdated.(event)

    @user.data.reload
    assert_equal "max", @user.data.membership_type
  end

  test "handles tier change from max to premium" do
    @user.data.update!(membership_type: "max")

    event = create_event(
      subscription_id: "sub_123",
      status: "active",
      price_id: Jiki.config.stripe_premium_price_id,
      with_items_change: true
    )

    Stripe::Webhook::SubscriptionUpdated.(event)

    @user.data.reload
    assert_equal "premium", @user.data.membership_type
  end

  test "does not change tier if price did not change" do
    @user.data.update!(membership_type: "premium")

    event = create_event(
      subscription_id: "sub_123",
      status: "active",
      price_id: Jiki.config.stripe_premium_price_id,
      with_items_change: false
    )

    Stripe::Webhook::SubscriptionUpdated.(event)

    @user.data.reload
    assert_equal "premium", @user.data.membership_type
  end

  test "raises ArgumentError for unknown price ID on tier change" do
    @user.data.update!(membership_type: "premium")

    event = create_event(
      subscription_id: "sub_123",
      status: "active",
      price_id: "price_unknown_xyz",
      with_items_change: true,
      skip_period_end: true,  # Don't stub since error is raised before we access it
      skip_status: true       # Don't stub since error is raised before we access it
    )

    error = assert_raises(ArgumentError) do
      Stripe::Webhook::SubscriptionUpdated.(event)
    end

    assert_match(/Unknown Stripe price ID/, error.message)
    assert_match(/price_unknown_xyz/, error.message)
  end

  private
  def create_event(subscription_id:, status: "active", price_id: nil, current_period_end: nil, with_items_change: false, skip_period_end: false, skip_status: false)
    price_id ||= Jiki.config.stripe_premium_price_id
    current_period_end ||= 1.month.from_now.to_i

    # Mock subscription items
    item = mock
    # Only stub current_period_end if not skipped (e.g., when testing early error)
    item.stubs(:current_period_end).returns(current_period_end) unless skip_period_end

    # Only stub price if with_items_change (tier change scenario)
    if with_items_change
      price = mock
      price.stubs(:id).returns(price_id)
      item.stubs(:price).returns(price)
    end

    items_data = mock
    items_data.stubs(:first).returns(item)

    items = mock
    items.stubs(:data).returns(items_data)

    subscription = mock
    subscription.stubs(:id).returns(subscription_id)
    subscription.stubs(:status).returns(status) unless skip_status
    subscription.stubs(:items).returns(items)

    # Mock previous attributes
    previous_attributes = with_items_change ? { 'items' => true } : {}

    event_data = mock
    event_data.stubs(:object).returns(subscription)
    event_data.stubs(:previous_attributes).returns(previous_attributes)

    event = mock
    event.stubs(:data).returns(event_data)

    event
  end
end
