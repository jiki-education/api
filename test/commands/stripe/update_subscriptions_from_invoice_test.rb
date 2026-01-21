require "test_helper"

class Stripe::UpdateSubscriptionsFromInvoiceTest < ActiveSupport::TestCase
  test "clears payment_failed_at when payment succeeds" do
    user = create(:user)
    user.data.update!(
      stripe_customer_id: "cus_123",
      subscriptions: [{
        'stripe_subscription_id' => "sub_123",
        'tier' => "premium",
        'started_at' => 1.month.ago.iso8601,
        'ended_at' => nil,
        'end_reason' => nil,
        'payment_failed_at' => 3.days.ago.iso8601
      }]
    )

    invoice = mock_invoice(subscription: "sub_123")

    # subscription.id not called when entry already exists
    Stripe::UpdateSubscriptionsFromInvoice.(user, invoice, nil)

    user.data.reload
    sub_entry = user.data.subscriptions.first
    assert_nil sub_entry["payment_failed_at"]
  end

  test "creates subscription entry for incomplete subscription on first payment" do
    user = create(:user)
    user.data.update!(
      stripe_customer_id: "cus_123",
      membership_type: "premium",
      subscriptions: []
    )

    invoice = mock_invoice(subscription: "sub_123")
    subscription = mock_subscription_with_id("sub_123")

    Stripe::UpdateSubscriptionsFromInvoice.(user, invoice, subscription)

    user.data.reload
    assert_equal 1, user.data.subscriptions.length
    sub_entry = user.data.subscriptions.first
    assert_equal "sub_123", sub_entry["stripe_subscription_id"]
    assert_equal "premium", sub_entry["tier"]
    refute_nil sub_entry["started_at"]
    assert_nil sub_entry["ended_at"]
    assert_nil sub_entry["end_reason"]
    assert_nil sub_entry["payment_failed_at"]
  end

  test "does not duplicate subscription entry if already exists" do
    user = create(:user)
    user.data.update!(
      stripe_customer_id: "cus_123",
      subscriptions: [{
        'stripe_subscription_id' => "sub_123",
        'tier' => "premium",
        'started_at' => 1.month.ago.iso8601,
        'ended_at' => nil,
        'end_reason' => nil,
        'payment_failed_at' => nil
      }]
    )

    invoice = mock_invoice(subscription: "sub_123")

    # subscription.id not called when entry already exists
    Stripe::UpdateSubscriptionsFromInvoice.(user, invoice, nil)

    user.data.reload
    assert_equal 1, user.data.subscriptions.length
  end

  test "returns early if invoice has no subscription" do
    user = create(:user)
    user.data.update!(
      stripe_customer_id: "cus_123",
      subscriptions: []
    )

    invoice = mock_invoice(subscription: nil)
    subscription = nil

    Stripe::UpdateSubscriptionsFromInvoice.(user, invoice, subscription)

    user.data.reload
    assert_empty user.data.subscriptions
  end

  private
  def mock_invoice(subscription: "sub_123")
    invoice = mock
    invoice.stubs(:subscription).returns(subscription)
    invoice
  end

  def mock_subscription_with_id(id)
    subscription = mock
    subscription.stubs(:id).returns(id)
    subscription
  end
end
