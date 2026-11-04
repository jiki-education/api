require "test_helper"

class Stripe::PremiumPurchase::ClearPendingTest < ActiveSupport::TestCase
  test "clears the matching pending purchase" do
    user = create(:user)
    user.data.update!(pending_premium_purchase_payment_intent_id: "pi_123", pending_premium_purchase_at: 1.day.ago)

    Stripe::PremiumPurchase::ClearPending.(user, "pi_123")

    user.data.reload
    assert_nil user.data.pending_premium_purchase_payment_intent_id
    assert_nil user.data.pending_premium_purchase_at
  end

  test "leaves a different pending purchase in place" do
    user = create(:user)
    user.data.update!(pending_premium_purchase_payment_intent_id: "pi_new", pending_premium_purchase_at: 1.day.ago)

    Stripe::PremiumPurchase::ClearPending.(user, "pi_old")

    assert_equal "pi_new", user.data.reload.pending_premium_purchase_payment_intent_id
  end
end
