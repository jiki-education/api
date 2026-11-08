require "test_helper"

class Stripe::Webhook::PurchaseCompletedTest < ActiveSupport::TestCase
  test "fulfils a paid purchase" do
    user = create(:user)

    Stripe::FulfillPurchase.expects(:call).with(user, "pi_123")

    Stripe::Webhook::PurchaseCompleted.(event_for(user:))
  end

  test "ignores subscription-mode sessions" do
    Stripe::FulfillPurchase.expects(:call).never

    Stripe::Webhook::PurchaseCompleted.(event_for(user: create(:user), mode: "subscription"))
  end

  test "marks an unpaid session as pending" do
    user = create(:user)

    Stripe::FulfillPurchase.expects(:call).never
    Stripe::MarkPurchasePending.expects(:call).with(user, "pi_123")

    Stripe::Webhook::PurchaseCompleted.(event_for(user:, payment_status: "unpaid"))
  end

  test "logs an error when the user is not found" do
    Stripe::FulfillPurchase.expects(:call).never
    Rails.logger.expects(:error).with("Premium purchase cs_123 completed but user not found")

    Stripe::Webhook::PurchaseCompleted.(event_for(user: nil))
  end

  private
  def event_for(user:, mode: "payment", payment_status: "paid")
    session = OpenStruct.new(
      id: "cs_123",
      mode:,
      payment_status:,
      payment_intent: "pi_123",
      metadata: user ? { "user_id" => user.id.to_s } : nil
    )
    OpenStruct.new(data: OpenStruct.new(object: session))
  end
end
