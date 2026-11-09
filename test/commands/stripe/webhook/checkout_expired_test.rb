require "test_helper"

class Stripe::Webhook::CheckoutExpiredTest < ActiveSupport::TestCase
  test "sends the abandoned checkout email" do
    user = create(:user)

    User::SendAbandonedCheckoutEmail.expects(:call).with(user)

    Stripe::Webhook::CheckoutExpired.(event_for(user:))
  end

  test "ignores subscription-mode sessions" do
    User::SendAbandonedCheckoutEmail.expects(:call).never

    Stripe::Webhook::CheckoutExpired.(event_for(user: create(:user), mode: "subscription"))
  end

  test "skips users who can no longer purchase premium" do
    user = create(:user)
    user.data.update!(pending_premium_purchase_at: Time.current)

    User::SendAbandonedCheckoutEmail.expects(:call).never

    Stripe::Webhook::CheckoutExpired.(event_for(user:))
  end

  test "logs an error when the user is not found" do
    User::SendAbandonedCheckoutEmail.expects(:call).never
    Rails.logger.expects(:error).with("Premium checkout cs_123 expired but user not found")

    Stripe::Webhook::CheckoutExpired.(event_for(user: nil))
  end

  private
  def event_for(user:, mode: "payment")
    session = OpenStruct.new(
      id: "cs_123",
      mode:,
      metadata: user ? { "user_id" => user.id.to_s } : nil
    )
    OpenStruct.new(data: OpenStruct.new(object: session))
  end
end
