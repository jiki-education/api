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

    # Determine our subscription_status from Stripe's status
    case subscription.status
    when 'incomplete'
      our_status = 'incomplete'
    when 'active', 'trialing'
      our_status = 'active'
    else
      our_status = 'active' # Default to active for other statuses
    end

    # Update subscriptions array
    update_subscriptions_array!

    # Update user's subscription data
    user.data.update!(
      membership_type: (our_status == 'incomplete' ? 'standard' : tier),
      stripe_subscription_id: subscription.id,
      stripe_subscription_status: subscription.status,
      subscription_status: our_status,
      subscription_valid_until: Time.zone.at(subscription.current_period_end)
    )

    Rails.logger.info("Subscription created for user #{user.id}: #{tier} (#{subscription.id})")

    # TODO: Queue welcome email when mailers are implemented
    # SubscriptionMailer.defer(:confirmed, user.id, tier:)
  end

  private
  def update_subscriptions_array!
    user_subscriptions << {
      stripe_subscription_id: subscription.id,
      tier: tier,
      started_at: Time.current.iso8601,
      ended_at: nil,
      end_reason: nil,
      payment_failed_at: nil
    }
    user.data.update!(subscriptions: user_subscriptions)
  end

  memoize
  def subscription = event.data.object

  memoize
  def user_subscriptions = user.data.subscriptions || []

  memoize
  def user
    User.joins(:data).find_by(user_data: { stripe_customer_id: subscription.customer })
  end

  memoize
  def price_id = subscription.items.data.first.price.id

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
