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

  test "skips premium users" do
    user = make_premium(create(:user))

    User::SendAbandonedCheckoutEmail.expects(:call).never

    Stripe::Webhook::CheckoutExpired.(event_for(user:))
  end

  test "does nothing when the user is not found" do
    User::SendAbandonedCheckoutEmail.expects(:call).never

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
