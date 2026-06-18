require "test_helper"

class Stripe::CreateCheckoutSessionTest < ActiveSupport::TestCase
  test "creates checkout session with existing customer" do
    user = create(:user)
    user.data.update!(stripe_customer_id: "cus_123")
    price_id = "price_123"
    return_url = "#{Jiki.config.frontend_base_url}/subscribe/complete"

    customer = mock
    customer.stubs(:id).returns("cus_123")
    Stripe::GetOrCreateCustomer.stubs(:call).with(user).returns(customer)

    session = mock

    ::Stripe::Checkout::Session.expects(:create).with(
      ui_mode: 'elements',
      currency: :usd,
      line_items: [
        {
          price: price_id,
          quantity: 1
        }
      ],
      mode: 'subscription',
      return_url: return_url,
      metadata: {
        user_id: user.id,
        price_id: price_id
      },
      subscription_data: {
        metadata: {
          user_id: user.id
        }
      },
      customer: "cus_123",
      customer_update: { address: 'auto', name: 'auto' }
    ).returns(session)

    result = Stripe::CreateCheckoutSession.(user, price_id, return_url, :usd)

    assert_equal session, result
  end

  test "passes customer_email when user has no stripe_customer_id" do
    user = create(:user, email: "alice@example.com")
    price_id = "price_123"
    return_url = "#{Jiki.config.frontend_base_url}/subscribe/complete"

    Stripe::GetOrCreateCustomer.expects(:call).never

    session = mock

    ::Stripe::Checkout::Session.expects(:create).with(
      ui_mode: 'elements',
      currency: :usd,
      line_items: [
        {
          price: price_id,
          quantity: 1
        }
      ],
      mode: 'subscription',
      return_url: return_url,
      metadata: {
        user_id: user.id,
        price_id: price_id
      },
      subscription_data: {
        metadata: {
          user_id: user.id
        }
      },
      customer_email: "alice@example.com"
    ).returns(session)

    result = Stripe::CreateCheckoutSession.(user, price_id, return_url, :usd)

    assert_equal session, result
  end

  test "passes currency to Stripe checkout session" do
    user = create(:user)
    price_id = "price_123"
    return_url = "#{Jiki.config.frontend_base_url}/subscribe/complete"

    ::Stripe::Checkout::Session.expects(:create).with(has_entry(currency: :inr)).returns(mock)

    Stripe::CreateCheckoutSession.(user, price_id, return_url, :inr)
  end
end
