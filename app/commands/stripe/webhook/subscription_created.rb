class Stripe::Webhook::SubscriptionCreated
  include Mandate

  initialize_with :event

  def call
    unless user
      Rails.logger.error("Subscription created but user not found for customer: #{subscription.customer}")
      return
    end

    # Update user's subscription data
    user.data.update!(
      membership_type: tier,
      stripe_subscription_id: subscription.id,
      stripe_subscription_status: subscription.status,
      subscription_current_period_end: Time.zone.at(subscription.current_period_end),
      payment_failed_at: nil
    )

    Rails.logger.info("Subscription created for user #{user.id}: #{tier} (#{subscription.id})")

    # TODO: Queue welcome email when mailers are implemented
    # SubscriptionMailer.defer(:confirmed, user.id, tier:)
  end

  private
  memoize
  def subscription
    event.data.object
  end

  memoize
  def user
    User.joins(:data).find_by(user_data: { stripe_customer_id: subscription.customer })
  end

  memoize
  def price_id
    subscription.items.data.first.price.id
  end

  memoize
  def tier
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
