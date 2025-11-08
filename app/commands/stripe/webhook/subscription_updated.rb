class Stripe::Webhook::SubscriptionUpdated
  include Mandate

  initialize_with :event

  def call
    unless user
      Rails.logger.error("Subscription updated but user not found for subscription: #{subscription.id}")
      return
    end

    # Check if price changed (upgrade/downgrade)
    handle_tier_change if previous_attributes.key?('items')

    # Check if cancellation was scheduled/unscheduled
    handle_cancellation_change

    # Update subscription status
    handle_status_change

    # Always update period end from subscription item
    subscription_item = subscription.items.data.first
    if subscription_item&.current_period_end
      user.data.update!(
        subscription_valid_until: Time.zone.at(subscription_item.current_period_end)
      )
    end

    Rails.logger.info("Subscription updated for user #{user.id}: status=#{subscription.status}")
  end

  private
  def update_subscriptions_array!
    user.data.update!(subscriptions: user_subscriptions)
  end

  def handle_tier_change
    new_price_id = subscription.items.data.first.price.id
    old_tier = user.data.membership_type
    new_tier = determine_tier(new_price_id)

    return unless old_tier != new_tier

    # Close old subscription entry in array by matching subscription ID
    if (current_sub = user_subscriptions.find { |s| s['stripe_subscription_id'] == subscription.id })
      current_sub['ended_at'] = Time.current.iso8601
      # Determine if upgrade or downgrade based on tier hierarchy: standard < premium < max
      tier_order = { 'standard' => 0, 'premium' => 1, 'max' => 2 }
      current_sub['end_reason'] = tier_order[new_tier] > tier_order[old_tier] ? 'upgraded' : 'downgraded'
    end

    # Open new subscription entry
    user_subscriptions << {
      stripe_subscription_id: subscription.id,
      tier: new_tier,
      started_at: Time.current.iso8601,
      ended_at: nil,
      end_reason: nil,
      payment_failed_at: nil
    }

    user.data.update!(
      membership_type: new_tier,
      subscriptions: user_subscriptions
    )

    Rails.logger.info("User #{user.id} tier changed: #{old_tier} -> #{new_tier}")

    # TODO: Queue appropriate email when mailers are implemented
    # if new_tier > old_tier
    #   SubscriptionMailer.defer(:upgraded, user.id, from_tier: old_tier, to_tier: new_tier)
    # else
    #   SubscriptionMailer.defer(:downgraded, user.id, from_tier: old_tier, to_tier: new_tier)
    # end
  end

  def handle_cancellation_change
    # Check if cancel_at_period_end changed
    if subscription.cancel_at_period_end && !user.data.subscription_status_cancelling?
      user.data.update!(subscription_status: 'cancelling')
      Rails.logger.info("User #{user.id} subscription set to cancelling")
    elsif !subscription.cancel_at_period_end && user.data.subscription_status_cancelling?
      # Cancellation was undone (e.g., via tier change)
      user.data.update!(subscription_status: 'active')
      Rails.logger.info("User #{user.id} subscription cancellation undone")
    end
  end

  def handle_status_change
    case subscription.status
    when 'active', 'trialing'
      # Don't override if subscription is set to cancel at period end (status should stay 'cancelling')
      new_status = subscription.cancel_at_period_end ? user.data.subscription_status : 'active'
      user.data.update!(
        stripe_subscription_status: subscription.status,
        subscription_status: new_status
      )
    when 'past_due'
      # Record payment failure in subscriptions array by matching subscription ID
      if (current_sub = user_subscriptions.find { |s| s['stripe_subscription_id'] == subscription.id })
        current_sub['payment_failed_at'] ||= Time.current.iso8601
      end

      user.data.update!(
        stripe_subscription_status: 'past_due',
        subscription_status: 'payment_failed',
        subscriptions: user_subscriptions
      )
    when 'unpaid'
      # Grace period expired, downgrade to standard
      user.data.update!(
        membership_type: 'standard',
        stripe_subscription_status: 'unpaid',
        subscription_status: 'payment_failed'
      )
      Rails.logger.info("User #{user.id} downgraded to standard due to unpaid subscription")
    when 'canceled'
      user.data.update!(stripe_subscription_status: 'canceled')
    else
      user.data.update!(stripe_subscription_status: subscription.status)
    end
  end

  memoize
  def subscription = event.data.object

  memoize
  def user_subscriptions = user.data.subscriptions || []

  memoize
  def user
    User.joins(:data).find_by(user_data: { stripe_subscription_id: subscription.id })
  end

  memoize
  def previous_attributes = event.data.previous_attributes || {}

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
