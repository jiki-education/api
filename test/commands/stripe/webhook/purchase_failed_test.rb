require "test_helper"

class Stripe::Webhook::PurchaseFailedTest < ActiveSupport::TestCase
  test "clears the pending purchase" do
    user = create(:user)

    Stripe::ClearPendingPurchase.expects(:call).with(user, "pi_123")

    Stripe::Webhook::PurchaseFailed.(event_for(user:))
  end

  test "ignores subscription-mode sessions" do
    Stripe::ClearPendingPurchase.expects(:call).never

    Stripe::Webhook::PurchaseFailed.(event_for(user: create(:user), mode: "subscription"))
  end

  test "logs an error when the user is not found" do
    Stripe::ClearPendingPurchase.expects(:call).never
    Rails.logger.expects(:error).with("Premium purchase cs_123 failed but user not found")

    Stripe::Webhook::PurchaseFailed.(event_for(user: nil))
  end

  private
  def event_for(user:, mode: "payment")
    session = OpenStruct.new(
      id: "cs_123",
      mode:,
      payment_intent: "pi_123",
      metadata: user ? { "user_id" => user.id.to_s } : nil
    )
    OpenStruct.new(data: OpenStruct.new(object: session))
  end
end
