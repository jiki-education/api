class Stripe::ReactivateSubscription
  include Mandate

  initialize_with :user

  def call
    # Validate user has subscription
    raise ArgumentError, "No active subscription" unless user.data.stripe_subscription_id.present?

    # Validate subscription is actually scheduled for cancellation
    raise ArgumentError, "Subscription is not scheduled for cancellation" unless user.data.subscription_status == 'cancelling'

    # Reactivate subscription in Stripe by removing cancel_at_period_end
    ::Stripe::Subscription.update(
      user.data.stripe_subscription_id,
      cancel_at_period_end: false
    )

    # Update status back to active
    user.data.update!(subscription_status: 'active')

    Rails.logger.info("User #{user.id} reactivated subscription #{user.data.stripe_subscription_id}")

    {
      success: true,
      subscription_valid_until: user.data.subscription_valid_until
    }
  end
end
