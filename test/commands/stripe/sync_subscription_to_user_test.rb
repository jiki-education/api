require "test_helper"

class Stripe::SyncSubscriptionToUserTest < ActiveSupport::TestCase
  test "sets active status and upgrades to premium for active subscription" do
    user = create(:user)
    user.data.update!(membership_type: "standard")

    subscription = mock_subscription(status: "active")

    status = Stripe::SyncSubscriptionToUser.(user, subscription, "monthly")

    assert_equal "active", status
    user.data.reload
    assert_equal "premium", user.data.membership_type
    assert_equal "sub_123", user.data.stripe_subscription_id
    assert_equal "active", user.data.stripe_subscription_status
    assert_equal "active", user.data.subscription_status
    assert_equal "monthly", user.data.subscription_interval
    refute_nil user.data.subscription_valid_until
  end

  test "sets active status for trialing subscription" do
    user = create(:user)

    subscription = mock_subscription(status: "trialing")

    status = Stripe::SyncSubscriptionToUser.(user, subscription, "monthly")

    assert_equal "active", status
    user.data.reload
    assert_equal "premium", user.data.membership_type
    assert_equal "active", user.data.subscription_status
  end

  test "sets subscription_interval to annual when specified" do
    user = create(:user)

    subscription = mock_subscription(status: "active")

    Stripe::SyncSubscriptionToUser.(user, subscription, "annual")

    user.data.reload
    assert_equal "annual", user.data.subscription_interval
  end

  test "sets subscription_interval to monthly when specified" do
    user = create(:user)

    subscription = mock_subscription(status: "active")

    Stripe::SyncSubscriptionToUser.(user, subscription, "monthly")

    user.data.reload
    assert_equal "monthly", user.data.subscription_interval
  end

  test "sets incomplete status and preserves membership_type for incomplete subscription" do
    user = create(:user)
    user.data.update!(membership_type: "premium")

    subscription = mock_subscription(status: "incomplete")

    status = Stripe::SyncSubscriptionToUser.(user, subscription, "annual")

    assert_equal "incomplete", status
    user.data.reload
    assert_equal "premium", user.data.membership_type
    assert_equal "sub_123", user.data.stripe_subscription_id
    assert_equal "incomplete", user.data.stripe_subscription_status
    assert_equal "incomplete", user.data.subscription_status
  end

  test "preserves standard membership_type for incomplete subscription when user has no prior subscription" do
    user = create(:user)
    user.data.update!(membership_type: "standard")

    subscription = mock_subscription(status: "incomplete")

    status = Stripe::SyncSubscriptionToUser.(user, subscription, "monthly")

    assert_equal "incomplete", status
    user.data.reload
    assert_equal "standard", user.data.membership_type
    assert_equal "incomplete", user.data.subscription_status
  end

  test "adds subscription to subscriptions array with interval" do
    user = create(:user)

    subscription = mock_subscription(status: "active")

    Stripe::SyncSubscriptionToUser.(user, subscription, "annual")

    user.data.reload
    assert_equal 1, user.data.subscriptions.length
    sub_entry = user.data.subscriptions.first
    assert_equal "sub_123", sub_entry["stripe_subscription_id"]
    assert_equal "premium", sub_entry["tier"]
    assert_equal "annual", sub_entry["interval"]
    refute_nil sub_entry["started_at"]
    assert_nil sub_entry["ended_at"]
    assert_nil sub_entry["end_reason"]
    assert_nil sub_entry["payment_failed_at"]
  end

  test "is idempotent - does not duplicate subscription entry if already exists" do
    user = create(:user)
    user.data.update!(
      subscriptions: [
        {
          "stripe_subscription_id" => "sub_123",
          "tier" => "premium",
          "interval" => "monthly",
          "started_at" => 1.hour.ago.iso8601,
          "ended_at" => nil,
          "end_reason" => nil,
          "payment_failed_at" => nil
        }
      ]
    )

    subscription = mock_subscription(status: "active")

    Stripe::SyncSubscriptionToUser.(user, subscription, "monthly")

    user.data.reload
    assert_equal 1, user.data.subscriptions.length
  end

  test "adds new subscription entry if different subscription id" do
    user = create(:user)
    user.data.update!(
      subscriptions: [
        {
          "stripe_subscription_id" => "sub_old",
          "tier" => "premium",
          "interval" => "monthly",
          "started_at" => 1.month.ago.iso8601,
          "ended_at" => 1.day.ago.iso8601,
          "end_reason" => "canceled",
          "payment_failed_at" => nil
        }
      ]
    )

    subscription = mock_subscription(status: "active", id: "sub_new")

    Stripe::SyncSubscriptionToUser.(user, subscription, "annual")

    user.data.reload
    assert_equal 2, user.data.subscriptions.length
    assert_equal "sub_new", user.data.subscriptions.last["stripe_subscription_id"]
    assert_equal "premium", user.data.subscriptions.last["tier"]
    assert_equal "annual", user.data.subscriptions.last["interval"]
  end

  private
  def mock_subscription(status:, id: "sub_123")
    subscription = mock
    subscription.expects(:id).returns(id).at_least_once
    subscription.expects(:status).returns(status).at_least_once

    item = mock
    item.expects(:current_period_end).returns(1.month.from_now.to_i).at_least_once
    items_data = mock
    items_data.expects(:data).returns([item]).at_least_once
    subscription.expects(:items).returns(items_data).at_least_once

    subscription
  end
end
