require "test_helper"

class Stripe::Webhook::PremiumPurchaseCompletedTest < ActiveSupport::TestCase
  test "fulfils a paid purchase" do
    user = create(:user)

    Stripe::PremiumPurchase::Fulfill.expects(:call).with(user, "pi_123")

    Stripe::Webhook::PremiumPurchaseCompleted.(event_for(user:))
  end

  test "ignores subscription-mode sessions" do
    Stripe::PremiumPurchase::Fulfill.expects(:call).never

    Stripe::Webhook::PremiumPurchaseCompleted.(event_for(user: create(:user), mode: "subscription"))
  end

  test "waits for an unpaid session to clear" do
    Stripe::PremiumPurchase::Fulfill.expects(:call).never

    Stripe::Webhook::PremiumPurchaseCompleted.(event_for(user: create(:user), payment_status: "unpaid"))
  end

  test "logs an error when the user is not found" do
    Stripe::PremiumPurchase::Fulfill.expects(:call).never
    Rails.logger.expects(:error).with("Premium purchase cs_123 paid but user not found")

    Stripe::Webhook::PremiumPurchaseCompleted.(event_for(user: nil))
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
