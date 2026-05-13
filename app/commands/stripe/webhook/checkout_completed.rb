class Stripe::Webhook::CheckoutCompleted
  include Mandate

  initialize_with :event

  def call
    unless user
      Rails.logger.error("Checkout completed but user not found for customer: #{session.customer}")
      return
    end

    user.data.with_lock do
      updates = {
        stripe_subscription_id: subscription_id,
        stripe_subscription_status: 'active'
      }
      updates[:stripe_customer_id] = session.customer if user.data.stripe_customer_id.blank? && session.customer.present?

      user.data.update!(**updates)
    end

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
    user_from_customer || user_from_metadata
  end

  def user_from_customer
    return nil if session.customer.blank?

    User.joins(:data).find_by(user_data: { stripe_customer_id: session.customer })
  end

  def user_from_metadata
    user_id = session.metadata&.[](:user_id) || session.metadata&.[]('user_id')
    user_id.present? ? User.find_by(id: user_id) : nil
  end
end
