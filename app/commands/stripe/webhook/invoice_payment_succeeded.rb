class Stripe::Webhook::InvoicePaymentSucceeded
  include Mandate

  initialize_with :event

  def call
    unless user
      Rails.logger.error("Invoice payment succeeded but user not found for customer: #{invoice.customer}")
      return
    end

    # Clear payment failure state
    user.data.update!(
      stripe_subscription_status: 'active',
      payment_failed_at: nil
    )

    Rails.logger.info("Invoice payment succeeded for user #{user.id}")
  end

  private
  memoize
  def invoice
    event.data.object
  end

  memoize
  def user
    User.joins(:data).find_by(user_data: { stripe_customer_id: invoice.customer })
  end
end
