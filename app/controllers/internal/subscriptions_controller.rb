class Internal::SubscriptionsController < Internal::BaseController
  # POST /internal/subscriptions/checkout_session
  # Creates a Stripe Checkout Session for subscribing to Premium
  def checkout_session
    interval = params[:interval] || "monthly"
    return_url = params[:return_url]

    # Validate interval
    unless %w[monthly annual].include?(interval)
      return render json: {
        error: {
          type: "invalid_interval",
          message: "Invalid interval. Must be 'monthly' or 'annual'"
        }
      }, status: :bad_request
    end

    # Block if user already has subscription
    unless current_user.data.can_checkout?
      return render json: {
        error: {
          type: "existing_subscription",
          message: "You already have a subscription. Use the update endpoint to change interval or cancel first."
        }
      }, status: :bad_request
    end

    # Validate return_url is from frontend
    unless Utils::VerifyFrontendUrl.(return_url)
      return render json: {
        error: {
          type: "invalid_return_url",
          message: "Return URL must be from #{Jiki.config.frontend_base_url}"
        }
      }, status: :bad_request
    end

    price_id = Stripe::DetermineSubscriptionDetails.price_id_for(interval)
    currency = current_user.currency

    # Create checkout session
    session = Stripe::CreateCheckoutSession.(current_user, price_id, return_url, currency)

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
      interval: result[:interval],
      payment_status: result[:payment_status],
      subscription_status: result[:subscription_status]
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

  # POST /internal/subscriptions/update
  # Updates subscription interval (monthly/annual)
  def update
    interval = params[:interval]

    # Validate interval
    unless %w[monthly annual].include?(interval)
      return render json: {
        error: {
          type: "invalid_interval",
          message: "Invalid interval. Must be 'monthly' or 'annual'"
        }
      }, status: :bad_request
    end

    # Check user can change plan
    unless current_user.data.can_change_interval?
      return render json: {
        error: {
          type: "no_subscription",
          message: "You don't have an active subscription. Use checkout to create one."
        }
      }, status: :bad_request
    end

    # Check not same interval
    if current_user.data.subscription_interval == interval
      return render json: {
        error: {
          type: "same_interval",
          message: "You are already on #{interval} billing"
        }
      }, status: :bad_request
    end

    # Update subscription
    result = Stripe::UpdateSubscription.(current_user, interval)

    render json: {
      success: result[:success],
      interval: result[:interval],
      effective_at: result[:effective_at],
      subscription_valid_until: result[:subscription_valid_until]
    }
  rescue ArgumentError => e
    Rails.logger.error("Invalid subscription update: #{e.message}")
    render json: {
      error: {
        type: "invalid_request",
        message: e.message
      }
    }, status: :unprocessable_entity
  rescue StandardError => e
    Rails.logger.error("Failed to update subscription: #{e.message}")
    render json: {
      error: {
        type: "update_failed",
        message: "Failed to update subscription"
      }
    }, status: :internal_server_error
  end

  # DELETE /internal/subscriptions/cancel
  # Cancels subscription at period end
  def cancel
    # Check user has subscription
    unless current_user.data.stripe_subscription_id.present?
      return render json: {
        error: {
          type: "no_subscription",
          message: "You don't have an active subscription"
        }
      }, status: :bad_request
    end

    # Cancel subscription
    result = Stripe::CancelSubscription.(current_user)

    render json: {
      success: result[:success],
      cancels_at: result[:cancels_at]
    }
  rescue StandardError => e
    Rails.logger.error("Failed to cancel subscription: #{e.message}")
    render json: {
      error: {
        type: "cancel_failed",
        message: "Failed to cancel subscription"
      }
    }, status: :internal_server_error
  end

  # POST /internal/subscriptions/reactivate
  # Reactivates a subscription that was scheduled for cancellation
  def reactivate
    # Check user has subscription
    unless current_user.data.stripe_subscription_id.present?
      return render json: {
        error: {
          type: "no_subscription",
          message: "You don't have an active subscription"
        }
      }, status: :bad_request
    end

    # Check subscription is actually scheduled for cancellation
    unless current_user.data.subscription_status == 'cancelling'
      return render json: {
        error: {
          type: "not_cancelling",
          message: "Subscription is not scheduled for cancellation"
        }
      }, status: :bad_request
    end

    # Reactivate subscription
    result = Stripe::ReactivateSubscription.(current_user)

    render json: {
      success: result[:success],
      subscription_valid_until: result[:subscription_valid_until]
    }
  rescue ArgumentError => e
    Rails.logger.error("Invalid subscription reactivation: #{e.message}")
    render json: {
      error: {
        type: "invalid_request",
        message: e.message
      }
    }, status: :unprocessable_entity
  rescue StandardError => e
    Rails.logger.error("Failed to reactivate subscription: #{e.message}")
    render json: {
      error: {
        type: "reactivate_failed",
        message: "Failed to reactivate subscription"
      }
    }, status: :internal_server_error
  end
end
