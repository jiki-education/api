class Stripe::Webhook::InvoicePaymentFailed
  include Mandate

  initialize_with :event

  def call
    unless user
      Rails.logger.error("Invoice payment failed but user not found for customer: #{invoice.customer}")
      return
    end

    return unless invoice.subscription.present?

    # Update subscriptions array
    update_subscriptions_array!

    # Set payment failure state (start grace period)
    user.data.update!(
      stripe_subscription_status: 'past_due',
      subscription_status: 'payment_failed'
    )

    Rails.logger.info("Invoice payment failed for user #{user.id}, grace period granted until #{user.data.grace_period_ends_at}")

    # TODO: Queue payment failed email when mailers are implemented
    # SubscriptionMailer.defer(:payment_failed, user.id)
  end

  private
  def update_subscriptions_array!
    # Record payment failure timestamp in subscription entry
    if (current_sub = user_subscriptions.find { |s| s['stripe_subscription_id'] == invoice.subscription })
      current_sub['payment_failed_at'] ||= Time.current.iso8601
      user.data.update!(subscriptions: user_subscriptions)
    end
  end

  memoize
  def invoice = event.data.object

  memoize
  def user_subscriptions = user.data.subscriptions || []

  memoize
  def user
    User.joins(:data).find_by(user_data: { stripe_customer_id: invoice.customer })
  end
end
