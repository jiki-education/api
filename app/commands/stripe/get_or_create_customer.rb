class Stripe::GetOrCreateCustomer
  include Mandate

  initialize_with :user

  def call
    # If user already has a Stripe customer ID, try to retrieve it
    if user.data.stripe_customer_id.present?
      begin
        return ::Stripe::Customer.retrieve(user.data.stripe_customer_id)
      rescue ::Stripe::InvalidRequestError => e
        # Customer was deleted in Stripe, we'll create a new one
        Rails.logger.warn("Stripe customer #{user.data.stripe_customer_id} not found for user #{user.id}: #{e.message}")
      end
    end

    # Create new customer in Stripe
    customer = ::Stripe::Customer.create(
      email: user.email,
      name: user.handle, # Using handle as name since we don't have a full name field yet
      metadata: {
        user_id: user.id,
        handle: user.handle
      }
    )

    # Save customer ID to database
    user.data.update!(stripe_customer_id: customer.id)

    customer
  end
end
