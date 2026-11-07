require "test_helper"

class Stripe::MarkPurchasePendingTest < ActiveSupport::TestCase
  test "records the pending purchase" do
    user = create(:user)

    freeze_time do
      Stripe::MarkPurchasePending.(user, "pi_123")

      user.data.reload
      assert_equal "pi_123", user.data.pending_premium_purchase_payment_intent_id
      assert_equal Time.current, user.data.pending_premium_purchase_at
    end
  end

  test "keeps the original timestamp when marked again" do
    user = create(:user)
    user.data.update!(pending_premium_purchase_payment_intent_id: "pi_123", pending_premium_purchase_at: 2.days.ago)

    Stripe::MarkPurchasePending.(user, "pi_123")

    assert_in_delta 2.days.ago.to_i, user.data.reload.pending_premium_purchase_at.to_i, 2
  end

  test "does nothing once the purchase has been fulfilled" do
    user = create(:user)
    create(:payment, :lifetime, user:, payment_processor_id: "pi_123")

    Stripe::MarkPurchasePending.(user, "pi_123")

    assert_nil user.data.reload.pending_premium_purchase_payment_intent_id
  end
end
