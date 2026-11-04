require "test_helper"

class Stripe::PremiumPurchase::CreateCheckoutSessionTest < ActiveSupport::TestCase
  test "creates a payment-mode session for the lifetime price" do
    user = create(:user)
    return_url = "#{Jiki.config.frontend_base_url}/premium/complete"
    price_id = Jiki.config.stripe_premium_lifetime_price_id
    session = mock

    Stripe::GetOrCreateCustomer.expects(:call).with(user).returns(stub(id: "cus_123"))
    ::Stripe::Checkout::Session.expects(:create).with(
      ui_mode: 'elements',
      mode: 'payment',
      currency: :gbp,
      customer: "cus_123",
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
    ).returns(session)

    assert_equal session, Stripe::PremiumPurchase::CreateCheckoutSession.(user, return_url, :gbp)
  end
end
