require "test_helper"

class Stripe::CreateCheckoutSessionTest < ActiveSupport::TestCase
  test "creates checkout session with correct parameters" do
    user = create(:user)
    price_id = "price_123"
    return_url = "#{Jiki.config.frontend_base_url}/subscribe/complete"

    customer = mock
    customer.stubs(:id).returns("cus_123")
    Stripe::GetOrCreateCustomer.stubs(:call).with(user).returns(customer)

    session = mock

    ::Stripe::Checkout::Session.expects(:create).with(
      ui_mode: 'custom',
      customer: "cus_123",
      line_items: [
        {
          price: price_id,
          quantity: 1
        }
      ],
      mode: 'subscription',
      billing_address_collection: 'required',
      adaptive_pricing: {
        enabled: true
      },
      return_url: return_url,
      subscription_data: {
        metadata: {
          user_id: user.id
        }
      }
    ).returns(session)

    result = Stripe::CreateCheckoutSession.(user, price_id, return_url)

    assert_equal session, result
  end

  test "creates checkout session with custom return_url when provided" do
    user = create(:user)
    price_id = "price_123"
    custom_url = "#{Jiki.config.frontend_base_url}/custom/path"

    customer = mock
    customer.stubs(:id).returns("cus_123")
    Stripe::GetOrCreateCustomer.stubs(:call).with(user).returns(customer)

    session = mock

    ::Stripe::Checkout::Session.expects(:create).with(
      ui_mode: 'custom',
      customer: "cus_123",
      line_items: [
        {
          price: price_id,
          quantity: 1
        }
      ],
      mode: 'subscription',
      billing_address_collection: 'required',
      adaptive_pricing: {
        enabled: true
      },
      return_url: custom_url,
      subscription_data: {
        metadata: {
          user_id: user.id
        }
      }
    ).returns(session)

    result = Stripe::CreateCheckoutSession.(user, price_id, custom_url)

    assert_equal session, result
  end

  test "gets or creates customer before creating session" do
    user = create(:user)
    price_id = "price_123"
    return_url = "#{Jiki.config.frontend_base_url}/subscribe/complete"

    Stripe::GetOrCreateCustomer.expects(:call).with(user).returns(mock(id: "cus_123"))
    ::Stripe::Checkout::Session.stubs(:create).returns(mock)

    Stripe::CreateCheckoutSession.(user, price_id, return_url)
  end
end
