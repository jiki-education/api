class Stripe::Webhook::CheckoutCompleted
  include Mandate

  initialize_with :event

  def call
    unless user
      Rails.logger.error("Checkout completed but user not found for customer: #{session.customer}")
      return
    end

    # Update user's subscription ID
    user.data.update!(
      stripe_subscription_id: subscription_id,
      stripe_subscription_status: 'active'
    )

    Rails.logger.info("Checkout completed for user #{user.id}, subscription: #{subscription_id}")
  end

  private
  memoize
  def session
    event.data.object
  end

  memoize
  def subscription_id
    session.subscription
  end

  memoize
  def user
    User.joins(:data).find_by(user_data: { stripe_customer_id: session.customer })
  end
end
