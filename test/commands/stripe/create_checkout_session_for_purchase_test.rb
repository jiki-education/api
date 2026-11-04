require "test_helper"

class Stripe::CreateCheckoutSessionForPurchaseTest < ActiveSupport::TestCase
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

    assert_equal session, Stripe::CreateCheckoutSessionForPurchase.(user, return_url, :gbp)
  end

  test "uses the low USD price for a low-tier country" do
    user = create(:user)
    user.data.update_column(:country_code, "EC")
    price_id = Jiki.config.stripe_premium_lifetime_low_usd_price_id

    Stripe::GetOrCreateCustomer.stubs(:call).returns(OpenStruct.new(id: "cus_123"))
    ::Stripe::Checkout::Session.expects(:create).with do |args|
      args[:currency] == :usd &&
        args[:line_items] == [{ price: price_id, quantity: 1 }] &&
        args[:metadata][:price_id] == price_id
    end

    Stripe::CreateCheckoutSessionForPurchase.(user, "#{Jiki.config.frontend_base_url}/premium/complete", :usd)
  end
end
