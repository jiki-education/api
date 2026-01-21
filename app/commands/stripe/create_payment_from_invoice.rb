class Stripe::CreatePaymentFromInvoice
  include Mandate

  initialize_with :user, :invoice, :subscription

  def call
    user.payments.create!(
      payment_processor_id: invoice.id,
      amount_in_cents: invoice.amount_paid,
      currency: invoice.currency,
      product: determine_product,
      external_receipt_url: invoice.hosted_invoice_url,
      data: {
        stripe_invoice_id: invoice.id,
        stripe_charge_id: invoice.charge,
        stripe_subscription_id: invoice.subscription,
        stripe_customer_id: invoice.customer,
        billing_reason: invoice.billing_reason,
        period_start: format_timestamp(subscription_item&.current_period_start),
        period_end: format_timestamp(subscription_item&.current_period_end)
      }
    )
  rescue ActiveRecord::RecordNotUnique
    user.payments.find_by!(payment_processor_id: invoice.id)
  end

  private
  def determine_product
    price_id = subscription_item&.price&.id
    case price_id
    when Jiki.config.stripe_premium_price_id
      'premium'
    when Jiki.config.stripe_max_price_id
      'max'
    else
      # Fallback to user's current membership type if price ID is not recognized
      user.data.membership_type == 'max' ? 'max' : 'premium'
    end
  end

  def subscription_item
    subscription&.items&.data&.first
  end

  def format_timestamp(unix_timestamp)
    return nil unless unix_timestamp

    Time.zone.at(unix_timestamp).iso8601
  end
end
