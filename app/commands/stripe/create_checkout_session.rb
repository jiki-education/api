class Stripe::CreateCheckoutSession
  include Mandate

  initialize_with :user, :price_id, :return_url, :currency

  def call
    args = {
      ui_mode: 'elements',
      currency: currency,
      line_items: [
        {
          price: price_id,
          quantity: 1
        }
      ],
      mode: 'subscription',
      return_url: return_url,
      metadata: {
        user_id: user.id
      },
      subscription_data: {
        metadata: {
          user_id: user.id
        }
      }
    }

    if user.data.stripe_customer_id.present?
      customer = Stripe::GetOrCreateCustomer.(user)
      args[:customer] = customer.id
      args[:customer_update] = { address: 'auto', name: 'auto' }
    else
      args[:customer_email] = user.email
    end

    ::Stripe::Checkout::Session.create(**args)
  end
end
