class SerializePayments
  include Mandate

  initialize_with :payments

  def call
    payments.map do |payment|
      {
        id: payment.id,
        amount_in_cents: payment.amount_in_cents,
        currency: payment.currency,
        product: payment.product,
        purchase_type: payment.purchase_type,
        revoked_reason: payment.revoked_reason,
        external_receipt_url: payment.external_receipt_url,
        paid_at: payment.created_at.iso8601
      }
    end
  end
end
