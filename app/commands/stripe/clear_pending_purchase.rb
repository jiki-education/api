class Stripe::ClearPendingPurchase
  include Mandate

  initialize_with :user, :payment_intent_id

  # Only clears the record for this purchase, so a stale event for an older
  # purchase can't unblock a newer one that is still clearing.
  def call
    user.data.with_lock do
      next unless user.data.pending_premium_purchase_payment_intent_id == payment_intent_id

      user.data.update!(
        pending_premium_purchase_payment_intent_id: nil,
        pending_premium_purchase_at: nil
      )
    end
  end
end
