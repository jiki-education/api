require "test_helper"

class Stripe::GetOrCreateCustomerTest < ActiveSupport::TestCase
  test "creates new Stripe customer when user has no stripe_customer_id" do
    user = create(:user)
    assert_nil user.data.stripe_customer_id

    customer = mock
    customer.stubs(:id).returns("cus_123")

    ::Stripe::Customer.expects(:create).with(
      email: user.email,
      name: user.handle,
      metadata: {
        user_id: user.id,
        handle: user.handle
      }
    ).returns(customer)

    result = Stripe::GetOrCreateCustomer.(user)

    assert_equal customer, result
    assert_equal "cus_123", user.data.reload.stripe_customer_id
  end

  test "retrieves existing Stripe customer when user has stripe_customer_id" do
    user = create(:user)
    user.data.update!(stripe_customer_id: "cus_existing")

    customer = mock
    ::Stripe::Customer.expects(:retrieve).with("cus_existing").returns(customer)

    result = Stripe::GetOrCreateCustomer.(user)

    assert_equal customer, result
  end

  test "creates new customer when existing customer is not found in Stripe" do
    user = create(:user)
    user.data.update!(stripe_customer_id: "cus_deleted")

    # Stripe::retrieve raises InvalidRequestError when customer doesn't exist
    ::Stripe::Customer.expects(:retrieve).with("cus_deleted").
      raises(::Stripe::InvalidRequestError.new("No such customer", "id"))

    new_customer = mock
    new_customer.stubs(:id).returns("cus_new")

    ::Stripe::Customer.expects(:create).returns(new_customer)

    result = Stripe::GetOrCreateCustomer.(user)

    assert_equal new_customer, result
    assert_equal "cus_new", user.data.reload.stripe_customer_id
  end
end
