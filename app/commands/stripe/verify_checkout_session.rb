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

    # Get the subscription item (should only be one for our use case)
    subscription_item = subscription.items.data.first
    raise ArgumentError, "Subscription has no items" unless subscription_item

    # Get the tier based on price ID
    tier = determine_tier(subscription_item.price.id)

    # Sync subscription to user (handles both active and incomplete states)
    status = Stripe::SyncSubscriptionToUser.(user, subscription, tier)

    Rails.logger.info("Verified checkout session #{session_id} for user #{user.id}: #{tier} (#{subscription.id}), status: #{status}")

    {
      success: true,
      tier: tier,
      payment_status: session.payment_status,
      subscription_status: status
    }
  end

  private
  def determine_tier(price_id)
    case price_id
    when Jiki.config.stripe_premium_price_id
      'premium'
    when Jiki.config.stripe_max_price_id
      'max'
    else
      raise ArgumentError,
        "Unknown Stripe price ID: #{price_id}. Expected #{Jiki.config.stripe_premium_price_id} or #{Jiki.config.stripe_max_price_id}"
    end
  end
end
