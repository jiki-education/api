class Stripe::VerifyCheckoutSession
  include Mandate

  initialize_with :user, :session_id

  def call
    # Retrieve the session from Stripe
    session = ::Stripe::Checkout::Session.retrieve(session_id)

    # Verify the session belongs to the current user
    raise SecurityError, "Checkout session does not belong to current user" unless session.customer == user.data.stripe_customer_id

    # Check if session is complete and has a subscription
    raise ArgumentError, "Checkout session is not complete (status: #{session.status})" unless session.status == "complete"

    raise ArgumentError, "Checkout session has no subscription" unless session.subscription.present?

    # Retrieve the full subscription object to get all details
    subscription = ::Stripe::Subscription.retrieve(session.subscription)

    # Get the tier based on price ID
    price_id = subscription.items.data.first.price.id
    tier = determine_tier(price_id)

    # Update user's subscription data (same as webhook handlers)
    user.data.update!(
      membership_type: tier,
      stripe_subscription_id: subscription.id,
      stripe_subscription_status: subscription.status,
      subscription_current_period_end: Time.zone.at(subscription.current_period_end),
      payment_failed_at: nil
    )

    Rails.logger.info("Verified checkout session #{session_id} for user #{user.id}: #{tier} (#{subscription.id})")

    { success: true, tier: tier }
  end

  private
  def determine_tier(price_id)
    case price_id
    when Jiki.config.stripe_premium_price_id
      'premium'
    when Jiki.config.stripe_max_price_id
      'max'
    else
      Rails.logger.warn("Unknown price ID: #{price_id}, defaulting to premium")
      'premium'
    end
  end
end
