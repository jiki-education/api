class Stripe::Webhook::InvoicePaymentSucceeded
  include Mandate

  initialize_with :event

  def call
    unless user
      Rails.logger.error("Invoice payment succeeded but user not found for customer: #{invoice.customer}")
      return
    end

    # Update subscriptions array
    update_subscriptions_array!

    # Reset to active status and normal period end
    return unless invoice.subscription.present?

    subscription_item = subscription.items.data.first
    return unless subscription_item&.current_period_end

    user.data.update!(
      stripe_subscription_status: 'active',
      subscription_status: 'active',
      subscription_valid_until: Time.zone.at(subscription_item.current_period_end)
    )

    Rails.logger.info("Invoice payment succeeded for user #{user.id}")
  end

  private
  def update_subscriptions_array!
    return unless invoice.subscription.present?

    # Find or create subscription entry
    current_sub = user_subscriptions.find { |s| s['stripe_subscription_id'] == invoice.subscription }

    if current_sub
      # Clear payment failure timestamp if present
      current_sub['payment_failed_at'] = nil
    else
      # Create new entry (handles incomplete → active transition)
      user_subscriptions << {
        stripe_subscription_id: subscription.id,
        tier: user.data.membership_type,
        started_at: Time.current.iso8601,
        ended_at: nil,
        end_reason: nil,
        payment_failed_at: nil
      }
    end

    # Save updated array to database
    user.data.update!(subscriptions: user_subscriptions)
  end

  memoize
  def invoice = event.data.object

  memoize
  def user_subscriptions = user.data.subscriptions || []

  memoize
  def subscription = Stripe::Subscription.retrieve(invoice.subscription)

  memoize
  def user
    User.joins(:data).find_by(user_data: { stripe_customer_id: invoice.customer })
  end
end
