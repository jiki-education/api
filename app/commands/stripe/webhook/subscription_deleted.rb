class Stripe::Webhook::SubscriptionDeleted
  include Mandate

  initialize_with :event

  def call
    unless user
      Rails.logger.error("Subscription deleted but user not found for subscription: #{subscription.id}")
      return
    end

    old_tier = user.data.membership_type

    # Downgrade to standard tier
    user.data.update!(
      membership_type: 'standard',
      stripe_subscription_status: 'canceled',
      stripe_subscription_id: nil,
      subscription_current_period_end: nil,
      payment_failed_at: nil
    )

    Rails.logger.info("Subscription deleted for user #{user.id}, downgraded from #{old_tier} to standard")

    # TODO: Queue cancellation email when mailers are implemented
    # SubscriptionMailer.defer(:cancelled, user.id)
  end

  private
  memoize
  def subscription
    event.data.object
  end

  memoize
  def user
    User.joins(:data).find_by(user_data: { stripe_subscription_id: subscription.id })
  end
end
