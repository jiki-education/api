class Stripe::Webhook::InvoicePaymentFailed
  include Mandate

  initialize_with :event

  def call
    unless user
      Rails.logger.error("Invoice payment failed but user not found for customer: #{invoice.customer}")
      return
    end

    # Set payment failure state (start grace period)
    user.data.update!(
      stripe_subscription_status: 'past_due',
      payment_failed_at: user.data.payment_failed_at || Time.current
    )

    Rails.logger.info("Invoice payment failed for user #{user.id}, grace period started")

    # TODO: Queue payment failed email when mailers are implemented
    # SubscriptionMailer.defer(:payment_failed, user.id)
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
