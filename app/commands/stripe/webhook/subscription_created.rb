class Stripe::Webhook::SubscriptionCreated
  include Mandate

  initialize_with :event

  def call
    # Early return for expired incomplete subscriptions
    return if subscription.status == 'incomplete_expired'

    unless user
      Rails.logger.error("Subscription created but user not found for customer: #{subscription.customer}")
      return
    end

    # Sync subscription to user (handles both active and incomplete states)
    Stripe::SyncSubscriptionToUser.(user, subscription, interval)

    Rails.logger.info("Subscription created for user #{user.id}: premium #{interval} (#{subscription.id})")
  end

  private
  memoize
  def subscription = event.data.object

  memoize
  def user
    User.joins(:data).find_by(user_data: { stripe_customer_id: subscription.customer })
  end

  memoize
  def price_id = subscription.items.data.first.price.id

  memoize
  def interval = Stripe::DetermineSubscriptionDetails.interval_for_price_id(price_id)
end
