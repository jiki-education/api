class Stripe::UpdateSubscription
  include Mandate

  initialize_with :user, :interval

  def call
    validate!

    # Retrieve subscription from Stripe
    subscription = ::Stripe::Subscription.retrieve(user.data.stripe_subscription_id)

    # Get subscription item ID
    subscription_item = subscription.items.data.first
    raise ArgumentError, "Subscription has no items" unless subscription_item

    new_price_id = Stripe::DetermineSubscriptionDetails.price_id_for(interval)

    # Monthly → annual charges immediately; annual → monthly creates prorations
    proration = interval == 'annual' ? 'always_invoice' : 'create_prorations'

    # Update subscription in Stripe
    updated_subscription = ::Stripe::Subscription.update(
      subscription.id,
      items: [{
        id: subscription_item.id,
        price: new_price_id
      }],
      proration_behavior: proration
    )

    # Get the updated subscription item
    updated_subscription_item = updated_subscription.items.data.first
    raise ArgumentError, "Updated subscription has no items" unless updated_subscription_item

    # Update interval and validity period
    user.data.update!(
      subscription_interval: interval,
      subscription_valid_until: Time.zone.at(updated_subscription_item.current_period_end)
    )

    Rails.logger.info("User #{user.id} changed to #{interval} billing")

    {
      success: true,
      interval: interval,
      effective_at: 'immediate',
      subscription_valid_until: Time.zone.at(updated_subscription_item.current_period_end)
    }
  end

  private
  def validate!
    raise ArgumentError, "No active subscription" unless user.data.stripe_subscription_id.present?
    raise ArgumentError, "Already on #{interval} billing" if user.data.subscription_interval == interval
  end
end
