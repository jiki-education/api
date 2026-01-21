class Stripe::Webhook::InvoicePaymentSucceeded
  include Mandate

  initialize_with :event

  def call
    unless user
      Rails.logger.error("Invoice payment succeeded but user not found for customer: #{invoice.customer}")
      return
    end

    return unless invoice.subscription.present?

    subscription_item = subscription.items.data.first
    return unless subscription_item&.current_period_end

    ActiveRecord::Base.transaction do
      Stripe::UpdateSubscriptionsFromInvoice.(user, invoice, subscription)
      Stripe::CreatePaymentFromInvoice.(user, invoice, subscription)

      # Reset to active status and normal period end
      user.data.update!(
        stripe_subscription_status: 'active',
        subscription_status: 'active',
        subscription_valid_until: Time.zone.at(subscription_item.current_period_end)
      )
    end

    Rails.logger.info("Invoice payment succeeded for user #{user.id}")
  end

  private
  memoize
  def invoice = event.data.object

  memoize
  def subscription = Stripe::Subscription.retrieve(invoice.subscription)

  memoize
  def user
    User.joins(:data).find_by(user_data: { stripe_customer_id: invoice.customer })
  end
end
