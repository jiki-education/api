class Stripe::Webhook::SubscriptionUpdated
  include Mandate

  initialize_with :event

  def call
    unless user
      Rails.logger.error("Subscription updated but user not found for subscription: #{subscription.id}")
      return
    end

    # Check if price changed (upgrade/downgrade)
    handle_tier_change(user, subscription) if previous_attributes.key?('items')

    # Update subscription status
    handle_status_change(user, subscription)

    # Always update current period end from subscription item
    subscription_item = subscription.items.data.first
    raise ArgumentError, "Subscription has no items" unless subscription_item
    raise ArgumentError, "Subscription item missing current_period_end" unless subscription_item.current_period_end

    user.data.update!(
      subscription_current_period_end: Time.zone.at(subscription_item.current_period_end)
    )

    Rails.logger.info("Subscription updated for user #{user.id}: status=#{subscription.status}")
  end

  private
  def handle_tier_change(user, subscription)
    new_price_id = subscription.items.data.first.price.id
    old_tier = user.data.membership_type
    new_tier = determine_tier(new_price_id)

    return unless old_tier != new_tier

    user.data.update!(membership_type: new_tier)
    Rails.logger.info("User #{user.id} tier changed: #{old_tier} -> #{new_tier}")

    # TODO: Queue appropriate email when mailers are implemented
    # if new_tier > old_tier
    #   SubscriptionMailer.defer(:upgraded, user.id, from_tier: old_tier, to_tier: new_tier)
    # else
    #   SubscriptionMailer.defer(:downgraded, user.id, from_tier: old_tier, to_tier: new_tier)
    # end
  end

  def handle_status_change(user, subscription)
    case subscription.status
    when 'active'
      # Subscription is active - clear any payment failures
      user.data.update!(
        stripe_subscription_status: 'active',
        payment_failed_at: nil
      )
    when 'past_due'
      # Payment failed - set payment_failed_at if not already set
      user.data.update!(
        stripe_subscription_status: 'past_due',
        payment_failed_at: user.data.payment_failed_at || Time.current
      )
    when 'canceled'
      # Subscription canceled - will be handled by subscription.deleted event
      user.data.update!(stripe_subscription_status: 'canceled')
    when 'unpaid'
      # Grace period expired, subscription is unpaid
      # Downgrade to standard tier
      user.data.update!(
        membership_type: 'standard',
        stripe_subscription_status: 'unpaid'
      )
      Rails.logger.info("User #{user.id} downgraded to standard due to unpaid subscription")
    else
      # Other statuses (trialing, incomplete, incomplete_expired, etc.)
      user.data.update!(stripe_subscription_status: subscription.status)
    end
  end

  memoize
  def subscription
    event.data.object
  end

  memoize
  def user
    User.joins(:data).find_by(user_data: { stripe_subscription_id: subscription.id })
  end

  memoize
  def previous_attributes
    event.data.previous_attributes || {}
  end

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
