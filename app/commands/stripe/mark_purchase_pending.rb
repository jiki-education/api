class Stripe::MarkPurchasePending
  include Mandate

  initialize_with :user, :payment_intent_id

  # Records a purchase whose payment (e.g. a bank debit) is still clearing, so
  # the user can't buy again in the meantime.
  def call
    user.data.with_lock do
      # A late verify call or webhook retry must not re-mark a purchase that
      # has already been fulfilled.
      next if user.payments.exists?(payment_processor_id: payment_intent_id)
      next if user.data.pending_premium_purchase_payment_intent_id == payment_intent_id

      user.data.update!(
        pending_premium_purchase_payment_intent_id: payment_intent_id,
        pending_premium_purchase_at: Time.current
      )
    end
  end
end
