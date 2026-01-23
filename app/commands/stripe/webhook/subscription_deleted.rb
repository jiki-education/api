class Stripe::Webhook::SubscriptionDeleted
  include Mandate

  initialize_with :event

  def call
    unless user
      Rails.logger.error("Subscription deleted but user not found for subscription: #{subscription.id}")
      return
    end

    old_tier = user.data.membership_type

    # Update subscriptions array
    update_subscriptions_array!

    # Downgrade to standard tier via dedicated command (sends email)
    User::DowngradeToStandard.(user)

    # Update remaining subscription fields
    user.data.update!(
      stripe_subscription_status: 'canceled',
      subscription_status: 'canceled',
      stripe_subscription_id: nil,
      subscription_valid_until: nil
    )

    Rails.logger.info("Subscription deleted for user #{user.id}, downgraded from #{old_tier} to standard")
  end

  private
  def update_subscriptions_array!
    # Determine end reason from status
    case user.data.stripe_subscription_status
    when 'past_due', 'unpaid'
      end_reason = 'payment_failed'
    else
      end_reason = 'canceled'
    end

    # Update subscription entry in array by matching subscription ID
    if (current_sub = user_subscriptions.find { |s| s['stripe_subscription_id'] == subscription.id })
      current_sub['ended_at'] = Time.current.iso8601
      current_sub['end_reason'] = end_reason
      user.data.update!(subscriptions: user_subscriptions)
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
end
