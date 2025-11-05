class Stripe::CreatePortalSession
  include Mandate

  initialize_with :user

  def call
    # User must have a Stripe customer ID to access the portal
    raise "User does not have a Stripe customer ID" unless user.data.stripe_customer_id.present?

    # Create Customer Portal session
    ::Stripe::BillingPortal::Session.create(
      customer: user.data.stripe_customer_id,
      return_url: "#{Jiki.config.frontend_base_url}/settings/subscription"
    )
  end
end
