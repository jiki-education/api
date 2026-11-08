require "test_helper"

class Stripe::RevokePurchaseTest < ActiveSupport::TestCase
  test "marks the payment revoked and revokes the stripe entitlement" do
    user = create(:user)
    payment = create(:payment, :lifetime, user:, payment_processor_id: "pi_123")

    User::PremiumEntitlement::Revoke.expects(:call).with(user, PremiumEntitlement::STRIPE_PURCHASE)

    freeze_time do
      Stripe::RevokePurchase.("pi_123", "refunded")

      payment.reload
      assert_equal Time.current.iso8601, payment.data["revoked_at"]
      assert_equal "refunded", payment.data["revoked_reason"]
    end
  end

  test "downgrades a user whose only premium came from the purchase" do
    user = create(:user)
    create(:payment, :lifetime, user:, payment_processor_id: "pi_123")
    User::PremiumEntitlement::Grant.(user, PremiumEntitlement::STRIPE_PURCHASE)
    assert user.reload.premium?

    Stripe::RevokePurchase.("pi_123", "disputed")

    assert user.reload.standard?
  end

  test "does nothing when the payment is already revoked" do
    user = create(:user)
    payment = create(:payment, :lifetime, user:, payment_processor_id: "pi_123")
    payment.update!(data: payment.data.merge("revoked_at" => 1.day.ago.iso8601, "revoked_reason" => "refunded"))

    User::PremiumEntitlement::Revoke.expects(:call).never

    Stripe::RevokePurchase.("pi_123", "disputed")

    assert_equal "refunded", payment.reload.data["revoked_reason"]
  end

  test "does nothing when no purchase matches" do
    User::PremiumEntitlement::Revoke.expects(:call).never

    Stripe::RevokePurchase.("pi_unknown", "refunded")
  end
end
