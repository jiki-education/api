class Stripe::UpdateSubscriptionsFromInvoice
  include Mandate

  initialize_with :user, :invoice, :subscription

  def call
    return unless subscription.present?

    # Find or create subscription entry
    current_sub = user_subscriptions.find { |s| s['stripe_subscription_id'] == subscription.id }

    if current_sub
      # Clear payment failure timestamp if present
      current_sub['payment_failed_at'] = nil
    else
      # Create new entry (handles incomplete → active transition)
      user_subscriptions << {
        stripe_subscription_id: subscription.id,
        tier: 'premium',
        interval: user.data.subscription_interval,
        started_at: Time.current.iso8601,
        ended_at: nil,
        end_reason: nil,
        payment_failed_at: nil
      }
    end

    # Save updated array to database
    user.data.update!(subscriptions: user_subscriptions)
  end

  private
  def user_subscriptions
    @user_subscriptions ||= user.data.subscriptions || []
  end
end
