require "test_helper"

class Stripe::CreatePortalSessionTest < ActiveSupport::TestCase
  test "creates portal session with correct parameters" do
    user = create(:user)
    user.data.update!(stripe_customer_id: "cus_123")

    session = mock

    ::Stripe::BillingPortal::Session.expects(:create).with(
      customer: "cus_123",
      return_url: "#{Jiki.config.frontend_base_url}/settings/subscription"
    ).returns(session)

    result = Stripe::CreatePortalSession.(user)

    assert_equal session, result
  end

  test "raises error when user has no stripe_customer_id" do
    user = create(:user)
    assert_nil user.data.stripe_customer_id

    error = assert_raises(RuntimeError) do
      Stripe::CreatePortalSession.(user)
    end

    assert_equal "User does not have a Stripe customer ID", error.message
  end
end
