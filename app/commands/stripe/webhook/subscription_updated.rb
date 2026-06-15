class Stripe::Webhook::SubscriptionUpdated
  include Mandate

  initialize_with :event

  def call
    unless user
      Rails.logger.error("Subscription updated but user not found for subscription: #{subscription.id}")
      return
    end

    # Check if price changed (interval change)
    handle_plan_change if previous_attributes.key?('items')

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
  def handle_plan_change
    new_price_id = subscription.items.data.first.price.id
    new_interval = Stripe::DetermineSubscriptionDetails.interval_for_price_id(new_price_id)
    old_interval = user.data.subscription_interval

    return if old_interval == new_interval

    # Close old subscription entry in array by matching subscription ID
    if (current_sub = user_subscriptions.find { |s| s['stripe_subscription_id'] == subscription.id && s['ended_at'].nil? })
      current_sub['ended_at'] = Time.current.iso8601
      current_sub['end_reason'] = 'interval_changed'
    end

    # Open new subscription entry (idempotent - check if already exists with new interval)
    unless user_subscriptions.any? do |s|
      s['stripe_subscription_id'] == subscription.id && s['interval'] == new_interval && s['ended_at'].nil?
    end
      user_subscriptions << {
        stripe_subscription_id: subscription.id,
        tier: 'premium',
        interval: new_interval,
        started_at: Time.current.iso8601,
        ended_at: nil,
        end_reason: nil,
        payment_failed_at: nil
      }
    end

    # Update subscriptions array and interval
    user.data.update!(
      subscriptions: user_subscriptions,
      subscription_interval: new_interval
    )

    Rails.logger.info("User #{user.id} interval changed: #{old_interval} -> #{new_interval}")
  end

  def handle_cancellation_change
    # Check if cancel_at_period_end changed
    if subscription.cancel_at_period_end && !user.data.subscription_status_cancelling?
      user.data.update!(subscription_status: 'cancelling')
      Rails.logger.info("User #{user.id} subscription set to cancelling")
    elsif !subscription.cancel_at_period_end && user.data.subscription_status_cancelling?
      # Cancellation was undone
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
      User::DowngradeToStandard.(user)
      user.data.update!(
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
end
