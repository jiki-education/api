class Stripe::VerifyCheckoutSession
  include Mandate

  initialize_with :user, :session_id

  def call
    session = ::Stripe::Checkout::Session.retrieve(session_id)

    verify_ownership!(session)

    raise ArgumentError, "Checkout session is not complete (status: #{session.status})" unless session.status == "complete"
    raise ArgumentError, "Checkout session has no subscription" unless session.subscription.present?

    persist_customer_id!(session)

    subscription = ::Stripe::Subscription.retrieve(session.subscription)

    subscription_item = subscription.items.data.first
    raise ArgumentError, "Subscription has no items" unless subscription_item

    interval = Stripe::DetermineSubscriptionDetails.interval_for_price_id(subscription_item.price.id)

    status = Stripe::SyncSubscriptionToUser.(user, subscription, interval)

    Rails.logger.info(
      "Verified checkout session #{session_id} for user #{user.id}: " \
      "premium #{interval} (#{subscription.id}), status: #{status}"
    )

    {
      success: true,
      interval: interval,
      payment_status: session.payment_status,
      subscription_status: status
    }
  end

  private
  def verify_ownership!(session)
    metadata_user_id = session.metadata&.[](:user_id) || session.metadata&.[]('user_id')

    if metadata_user_id.present?
      return if metadata_user_id.to_s == user.id.to_s
    elsif user.data.stripe_customer_id.present? && session.customer == user.data.stripe_customer_id
      return
    end

    raise SecurityError, "Checkout session does not belong to current user"
  end

  def persist_customer_id!(session)
    return if user.data.stripe_customer_id.present?
    return if session.customer.blank?

    user.data.update!(stripe_customer_id: session.customer)
  end
end
