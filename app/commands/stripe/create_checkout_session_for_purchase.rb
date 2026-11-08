class Stripe::CreateCheckoutSessionForPurchase
  include Mandate

  initialize_with :user, :return_url, :currency

  def call
    ::Stripe::Checkout::Session.create(
      ui_mode: 'elements',
      mode: 'payment',
      currency: currency,
      customer: customer.id,
      customer_update: { address: 'auto', name: 'auto' },
      line_items: [{ price: price_id, quantity: 1 }],
      return_url: return_url,
      metadata: {
        user_id: user.id,
        price_id: price_id
      },
      payment_intent_data: {
        metadata: { user_id: user.id }
      }
    )
  end

  private
  # The Customer is created up front (rather than leaving Checkout to create a
  # guest one) so every purchase is tied to a Customer that maps back to the user.
  memoize
  def customer = Stripe::GetOrCreateCustomer.(user)

  memoize
  def price_id = Pricing::DeterminePrices.(user.data.country_code)[:lifetime_price_id]
end
