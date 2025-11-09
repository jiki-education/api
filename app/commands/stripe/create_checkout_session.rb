class Stripe::CreateCheckoutSession
  include Mandate

  initialize_with :user, :price_id, :return_url

  def call
    # Get or create Stripe customer
    customer = Stripe::GetOrCreateCustomer.(user)

    # Create checkout session
    ::Stripe::Checkout::Session.create(
      ui_mode: 'custom',
      customer: customer.id,
      line_items: [
        {
          price: price_id,
          quantity: 1
        }
      ],
      mode: 'subscription',
      adaptive_pricing: {
        enabled: true
      },

      return_url: return_url,
      subscription_data: {
        metadata: {
          user_id: user.id
        }
      }
    )
  end
end
