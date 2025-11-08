class Stripe::CreatePortalSession
  include Mandate

  initialize_with :user

  def call
    # User must have a Stripe customer ID to access the portal
    raise "User does not have a Stripe customer ID" unless user.data.stripe_customer_id.present?

    # Create Customer Portal session with limited features
    # Disable subscription updates and cancellations
    ::Stripe::BillingPortal::Session.create(
      customer: user.data.stripe_customer_id,
      return_url: "#{Jiki.config.frontend_base_url}/settings/subscription",
      configuration: portal_configuration_id
    )
  end

  private
  def portal_configuration_id
    # Retrieve or create a portal configuration that disables subscription management
    configurations = ::Stripe::BillingPortal::Configuration.list(limit: 1, active: true)

    if configurations.data.any?
      configurations.data.first.id
    else
      create_portal_configuration
    end
  end

  def create_portal_configuration
    config = ::Stripe::BillingPortal::Configuration.create(
      features: {
        subscription_update: { enabled: false },
        subscription_cancel: { enabled: false }
      },
      business_profile: {
        headline: "Manage your Jiki subscription"
      }
    )
    config.id
  end
end
