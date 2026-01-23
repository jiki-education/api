class Stripe::SyncSubscriptionToUser
  include Mandate

  initialize_with :user, :subscription, :tier

  def call
    ActiveRecord::Base.transaction do
      update_user_data!
      update_subscriptions_array!
    end
    status
  end

  private
  memoize
  def status = subscription.status == 'incomplete' ? 'incomplete' : 'active'

  def update_user_data!
    # Handle membership changes via dedicated commands for active subscriptions
    if status == 'active'
      case tier
      when 'premium' then User::UpgradeToPremium.(user)
      when 'max' then User::UpgradeToMax.(user)
      end
    end
    # For incomplete status, membership_type is unchanged (handled by commands' early return)

    user.data.update!(
      stripe_subscription_id: subscription.id,
      stripe_subscription_status: subscription.status,
      subscription_status: status,
      subscription_valid_until: Time.zone.at(subscription_item.current_period_end)
    )
  end

  def update_subscriptions_array!
    # Idempotent - only add if not already present
    return if subscriptions.any? { |s| s['stripe_subscription_id'] == subscription.id }

    subscriptions << {
      stripe_subscription_id: subscription.id,
      tier: tier,
      started_at: Time.current.iso8601,
      ended_at: nil,
      end_reason: nil,
      payment_failed_at: nil
    }
    user.data.update!(subscriptions: subscriptions)
  end

  memoize
  def subscriptions = user.data.subscriptions || []

  memoize
  def subscription_item = subscription.items.data.first
end
