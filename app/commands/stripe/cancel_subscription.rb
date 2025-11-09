class Stripe::CancelSubscription
  include Mandate

  initialize_with :user

  def call
    # Validate user has subscription
    raise ArgumentError, "No active subscription" unless user.data.stripe_subscription_id.present?

    # Cancel subscription at period end
    ::Stripe::Subscription.update(
      user.data.stripe_subscription_id,
      cancel_at_period_end: true
    )

    # Update status to cancelling
    user.data.update!(subscription_status: 'cancelling')

    Rails.logger.info("User #{user.id} subscription set to cancel at #{user.data.subscription_valid_until}")

    {
      success: true,
      cancels_at: user.data.subscription_valid_until
    }
  end
end
