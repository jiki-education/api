class Internal::SubscriptionsController < Internal::BaseController
  # POST /internal/subscriptions/checkout_session
  # Creates a Stripe Checkout Session for upgrading to Premium or Max
  def checkout_session
    product = params[:product]
    return_url = params[:return_url]

    # Validate product and get corresponding price_id
    unless %w[premium max].include?(product)
      return render json: {
        error: {
          type: "invalid_product",
          message: "Invalid product. Must be 'premium' or 'max'"
        }
      }, status: :bad_request
    end

    # Validate return_url is provided and secure
    unless return_url.present?
      return render json: {
        error: {
          type: "missing_return_url",
          message: "return_url is required"
        }
      }, status: :bad_request
    end

    unless return_url.start_with?(Jiki.config.frontend_base_url)
      return render json: {
        error: {
          type: "invalid_return_url",
          message: "Return URL must start with #{Jiki.config.frontend_base_url}"
        }
      }, status: :bad_request
    end

    if product == "premium"
      price_id = Jiki.config.stripe_premium_price_id
    else
      price_id = Jiki.config.stripe_max_price_id
    end

    # Create checkout session
    session = Stripe::CreateCheckoutSession.(current_user, price_id, return_url)

    # Stripe Ruby gem bug: client_secret is URL-encoded in the response
    # We need to decode it before sending to the frontend
    # See: https://github.com/stripe/stripe-ruby/issues (URL encoding bug)
    client_secret = CGI.unescape(session.client_secret)

    render json: {
      client_secret: client_secret
    }
  rescue StandardError => e
    Rails.logger.error("Failed to create checkout session: #{e.message}")
    render json: {
      error: {
        type: "checkout_failed",
        message: "Failed to create checkout session"
      }
    }, status: :internal_server_error
  end

  # POST /internal/subscriptions/portal_session
  # Creates a Stripe Customer Portal session for managing subscriptions
  def portal_session
    unless current_user.data.stripe_customer_id.present?
      return render json: {
        error: {
          type: "no_customer",
          message: "No Stripe customer found"
        }
      }, status: :bad_request
    end

    session = Stripe::CreatePortalSession.(current_user)

    render json: {
      url: session.url
    }
  rescue StandardError => e
    Rails.logger.error("Failed to create portal session: #{e.message}")
    render json: {
      error: {
        type: "portal_failed",
        message: "Failed to create portal session"
      }
    }, status: :internal_server_error
  end

  # POST /internal/subscriptions/verify_checkout
  # Verifies a completed checkout session and syncs subscription data immediately
  def verify_checkout
    session_id = params[:session_id]

    unless session_id.present?
      return render json: {
        error: {
          type: "missing_session_id",
          message: "session_id is required"
        }
      }, status: :bad_request
    end

    result = Stripe::VerifyCheckoutSession.(current_user, session_id)

    render json: {
      success: result[:success],
      tier: result[:tier]
    }
  rescue SecurityError => e
    Rails.logger.error("Security error verifying checkout: #{e.message}")
    render json: {
      error: {
        type: "unauthorized",
        message: "Checkout session does not belong to current user"
      }
    }, status: :forbidden
  rescue ArgumentError => e
    Rails.logger.error("Invalid checkout session: #{e.message}")
    render json: {
      error: {
        type: "invalid_session",
        message: e.message
      }
    }, status: :unprocessable_entity
  rescue StandardError => e
    Rails.logger.error("Failed to verify checkout session: #{e.message}")
    render json: {
      error: {
        type: "verification_failed",
        message: "Failed to verify checkout session"
      }
    }, status: :internal_server_error
  end

  # GET /internal/subscriptions/status
  # Returns the current subscription status for the authenticated user
  def status
    render json: {
      subscription: {
        tier: current_user.data.membership_type,
        status: current_user.data.stripe_subscription_status || "none",
        current_period_end: current_user.data.subscription_current_period_end,
        payment_failed: !current_user.data.subscription_paid?,
        in_grace_period: current_user.data.in_grace_period?,
        grace_period_ends_at: current_user.data.grace_period_ends_at
      }
    }
  end
end
