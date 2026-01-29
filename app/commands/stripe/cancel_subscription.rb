class Stripe::CancelSubscription
  include Mandate

  initialize_with :user, cancel_immediately: false

  def call
    return unless user.data&.stripe_subscription_id.present?

    inform_stripe!
    update_user!
  rescue ::Stripe::InvalidRequestError => e
    raise unless e.message.include?("No such subscription")

    Rails.logger.info(
      "Subscription #{user.data.stripe_subscription_id} already deleted in Stripe for user #{user.id}"
    )
  rescue ::Stripe::StripeError => e
    raise StripeSubscriptionCancellationError, "Stripe error: #{e.message}"
  end

  private
  def inform_stripe!
    if cancel_immediately
      ::Stripe::Subscription.cancel(user.data.stripe_subscription_id)
    else
      ::Stripe::Subscription.update(user.data.stripe_subscription_id, cancel_at_period_end: true)
    end
  end

  def update_user!
    status = cancel_immediately ? 'canceled' : 'cancelling'
    user.data.update!(subscription_status: status)
  end
end
