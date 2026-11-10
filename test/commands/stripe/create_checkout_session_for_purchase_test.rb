require "test_helper"

class Stripe::CreateCheckoutSessionForPurchaseTest < ActiveSupport::TestCase
  test "creates a payment-mode session for the lifetime price" do
    user = create(:user)
    user.data.update!(stripe_customer_id: "cus_123")
    return_url = "#{Jiki.config.frontend_base_url}/premium/complete"
    price_id = Jiki.config.stripe_premium_lifetime_price_id
    session = mock

    freeze_time
    Stripe::GetOrCreateCustomer.expects(:call).never
    ::Stripe::Checkout::Session.expects(:create).with(
      ui_mode: 'elements',
      mode: 'payment',
      currency: :gbp,
      line_items: [{ price: price_id, quantity: 1 }],
      return_url: return_url,
      metadata: {
        user_id: user.id,
        price_id: price_id
      },
      payment_intent_data: {
        metadata: { user_id: user.id }
      },
      expires_at: 2.hours.from_now.to_i,
      customer: "cus_123",
      customer_update: { address: 'auto', name: 'auto' }
    ).returns(session)

    assert_equal session, Stripe::CreateCheckoutSessionForPurchase.(user, return_url, :gbp)
  end

  test "leaves Checkout to create the customer for a first-time buyer" do
    user = create(:user)

    Stripe::GetOrCreateCustomer.expects(:call).never
    ::Stripe::Customer.expects(:create).never
    ::Stripe::Checkout::Session.expects(:create).with do |args|
      args[:customer_email] == user.email &&
        args[:customer_creation] == 'always' &&
        !args.key?(:customer) &&
        !args.key?(:customer_update)
    end

    Stripe::CreateCheckoutSessionForPurchase.(user, "#{Jiki.config.frontend_base_url}/premium/complete", :gbp)
  end

  test "uses the low USD price for a low-tier country" do
    user = create(:user)
    user.data.update_column(:country_code, "EC")
    price_id = Jiki.config.stripe_premium_lifetime_low_usd_price_id

    ::Stripe::Checkout::Session.expects(:create).with do |args|
      args[:currency] == :usd &&
        args[:line_items] == [{ price: price_id, quantity: 1 }] &&
        args[:metadata][:price_id] == price_id
    end

    Stripe::CreateCheckoutSessionForPurchase.(user, "#{Jiki.config.frontend_base_url}/premium/complete", :usd)
  end
end
