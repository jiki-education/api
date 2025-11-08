require "test_helper"

class Stripe::CreatePortalSessionTest < ActiveSupport::TestCase
  test "creates portal session with correct parameters and configuration" do
    user = create(:user)
    user.data.update!(stripe_customer_id: "cus_123")

    session = mock
    config = mock
    config.stubs(:id).returns("bpc_123")

    # Mock the configuration list call to return existing config
    list_response = mock
    list_response.stubs(:data).returns([config])
    ::Stripe::BillingPortal::Configuration.expects(:list).with(limit: 1, active: true).returns(list_response)

    ::Stripe::BillingPortal::Session.expects(:create).with(
      customer: "cus_123",
      return_url: "#{Jiki.config.frontend_base_url}/settings/subscription",
      configuration: "bpc_123"
    ).returns(session)

    result = Stripe::CreatePortalSession.(user)

    assert_equal session, result
  end

  test "creates new portal configuration if none exists" do
    user = create(:user)
    user.data.update!(stripe_customer_id: "cus_123")

    session = mock
    config = mock
    config.stubs(:id).returns("bpc_new")

    # Mock the configuration list call to return empty
    list_response = mock
    list_response.stubs(:data).returns([])
    ::Stripe::BillingPortal::Configuration.expects(:list).with(limit: 1, active: true).returns(list_response)

    # Expect configuration creation with disabled features
    ::Stripe::BillingPortal::Configuration.expects(:create).with(
      features: {
        subscription_update: { enabled: false },
        subscription_cancel: { enabled: false }
      },
      business_profile: {
        headline: "Manage your Jiki subscription"
      }
    ).returns(config)

    ::Stripe::BillingPortal::Session.expects(:create).with(
      customer: "cus_123",
      return_url: "#{Jiki.config.frontend_base_url}/settings/subscription",
      configuration: "bpc_new"
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
