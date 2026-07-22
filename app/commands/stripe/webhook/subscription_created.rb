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

    # Ensure the Stripe customer is linked. When we resolved the user via
    # subscription metadata (because checkout.session.completed never set the
    # customer id), link it now so future subscription.updated/deleted webhooks
    # can find the user by customer id.
    link_customer!

    # Sync subscription to user (handles both active and incomplete states)
    Stripe::SyncSubscriptionToUser.(user, subscription, interval)

    Rails.logger.info("Subscription created for user #{user.id}: premium #{interval} (#{subscription.id})")
  end

  private
  memoize
  def subscription = event.data.object

  # Resolve the user by Stripe customer id, falling back to the user_id we
  # stamp into the subscription metadata at checkout. The fallback prevents a
  # dropped or out-of-order checkout.session.completed webhook (which is what
  # sets the customer id) from silently stranding a paid subscriber.
  memoize
  def user
    user_from_customer || user_from_metadata
  end

  def user_from_customer
    return nil if subscription.customer.blank?

    User.joins(:data).find_by(user_data: { stripe_customer_id: subscription.customer })
  end

  def user_from_metadata
    user_id = subscription.metadata&.[](:user_id) || subscription.metadata&.[]('user_id')
    user_id.present? ? User.find_by(id: user_id) : nil
  end

  def link_customer!
    return if subscription.customer.blank?
    return if user.data.stripe_customer_id.present?

    user.data.update!(stripe_customer_id: subscription.customer)
  end

  memoize
  def price_id = subscription.items.data.first.price.id

  memoize
  def interval = Stripe::DetermineSubscriptionDetails.interval_for_price_id(price_id)
end
