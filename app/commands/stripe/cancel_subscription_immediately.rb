class Stripe::CancelSubscriptionImmediately
  include Mandate

  initialize_with :user

  def call
    return unless user.data&.stripe_subscription_id.present?

    ::Stripe::Subscription.cancel(user.data.stripe_subscription_id)

    Rails.logger.info(
      "Immediately canceled Stripe subscription #{user.data.stripe_subscription_id} " \
      "for user #{user.id} (account deletion)"
    )
  rescue ::Stripe::InvalidRequestError => e
    # Subscription may already be canceled in Stripe - that's fine
    if e.message.include?("No such subscription")
      Rails.logger.info(
        "Subscription #{user.data.stripe_subscription_id} already deleted in Stripe for user #{user.id}"
      )
      return
    end
    raise StripeSubscriptionCancellationError, "Failed to cancel subscription: #{e.message}"
  rescue ::Stripe::StripeError => e
    raise StripeSubscriptionCancellationError, "Stripe error: #{e.message}"
  end
end
