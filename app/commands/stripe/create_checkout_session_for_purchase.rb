class Stripe::CreateCheckoutSessionForPurchase
  include Mandate

  initialize_with :user, :return_url, :currency

  def call
    ::Stripe::Checkout::Session.create(
      ui_mode: 'elements',
      mode: 'payment',
      currency: currency,
      line_items: [{ price: price_id, quantity: 1 }],
      return_url: return_url,
      metadata: {
        user_id: user.id,
        price_id: price_id
      },
      payment_intent_data: {
        metadata: { user_id: user.id }
      },
      **customer_args
    )
  end

  private
  # A user who has paid before keeps their existing Customer. Anyone else gets a
  # real Customer created by Checkout when the payment completes, which
  # Stripe::FulfillPurchase then links to the user. Creating it on completion
  # keeps the Stripe Customer list to people who actually paid. Opening checkout
  # and walking away leaves nothing behind.
  def customer_args
    if user.data.stripe_customer_id.present?
      {
        customer: Stripe::GetOrCreateCustomer.(user).id,
        customer_update: { address: 'auto', name: 'auto' }
      }
    else
      { customer_email: user.email, customer_creation: 'always' }
    end
  end

  memoize
  def price_id = Pricing::DeterminePrices.(user.data.country_code)[:lifetime_price_id]
end
