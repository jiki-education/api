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
    price_id = subscription_item.price.id
    tier = determine_tier(price_id)

    # Validate we have required fields
    raise ArgumentError, "Subscription item missing current_period_end" unless subscription_item.current_period_end

    # Update user's subscription data (same as webhook handlers)
    user.data.update!(
      membership_type: tier,
      stripe_subscription_id: subscription.id,
      stripe_subscription_status: subscription.status,
      subscription_status: 'active',
      subscription_valid_until: Time.zone.at(subscription_item.current_period_end)
    )

    # Initialize subscriptions array
    subscriptions_array = user.data.subscriptions || []
    subscriptions_array << {
      stripe_subscription_id: subscription.id,
      tier: tier,
      started_at: Time.current.iso8601,
      ended_at: nil,
      end_reason: nil,
      payment_failed_at: nil
    }
    user.data.update!(subscriptions: subscriptions_array)

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
      raise ArgumentError,
        "Unknown Stripe price ID: #{price_id}. Expected #{Jiki.config.stripe_premium_price_id} or #{Jiki.config.stripe_max_price_id}"
    end
  end
end
