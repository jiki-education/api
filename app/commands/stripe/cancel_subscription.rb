class Stripe::CancelSubscription
  include Mandate

  initialize_with :user, cancel_immediately: false

  def call
    return unless user.data&.stripe_subscription_id.present?

    inform_stripe!
    update_user!
    result
  rescue ::Stripe::InvalidRequestError => e
    raise unless e.message.include?("No such subscription")

    # The subscription is already gone in Stripe, so there's nothing left
    # to cancel. Mark it canceled locally and treat this as a success.
    Rails.logger.info(
      "Subscription #{user.data.stripe_subscription_id} already deleted in Stripe for user #{user.id}"
    )
    user.data.update!(subscription_status: 'canceled')
    result
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

  # cancels_at is when access ends: now for an immediate cancel, otherwise the
  # end of the period the user has paid for (also correct when the subscription
  # was already deleted in Stripe; nil if we never recorded a paid-until date).
  def result
    {
      success: true,
      cancels_at: cancel_immediately ? Time.current : user.data.subscription_valid_until
    }
  end
end
