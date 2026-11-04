class Internal::PremiumPurchasesController < Internal::BaseController
  # POST /internal/premium_purchases/checkout_session
  # Creates a Stripe Checkout Session for a one-off lifetime Premium purchase
  def checkout_session
    unless current_user.data.can_purchase_premium?
      Sentry.capture_message(
        "Premium purchase rejected: already premium",
        level: :error,
        extra: { user_id: current_user.id, subscription_status: current_user.data.subscription_status }
      )
      return render json: { error: { type: "already_premium" } }, status: :bad_request
    end

    unless Utils::VerifyFrontendUrl.(params[:return_url])
      Sentry.capture_message(
        "Premium purchase rejected: invalid return_url",
        level: :error,
        extra: { user_id: current_user.id, return_url: params[:return_url] }
      )
      return render json: { error: { type: "invalid_return_url" } }, status: :bad_request
    end

    currency = current_user.currency
    session = Stripe::PremiumPurchase::CreateCheckoutSession.(current_user, params[:return_url], currency)

    Analytics::TrackEvent.defer(
      current_user,
      "checkout_started",
      properties: {
        plan: "premium",
        interval: "lifetime",
        currency: currency,
        trigger: params[:trigger]
      }.compact
    )

    # The Stripe Ruby gem returns client_secret URL-encoded, so decode it before
    # sending it to the front-end.
    render json: { client_secret: URI.decode_www_form_component(session.client_secret) }
  rescue StandardError => e
    Rails.logger.error("Failed to create premium purchase checkout session: #{e.message}")
    Sentry.capture_exception(e, extra: { user_id: current_user.id })
    render json: { error: { type: "checkout_failed" } }, status: :internal_server_error
  end

  # POST /internal/premium_purchases/verify_checkout
  # Verifies a completed checkout session and grants Premium immediately if paid
  def verify_checkout
    return render json: { error: { type: "missing_session_id" } }, status: :bad_request if params[:session_id].blank?

    result = Stripe::PremiumPurchase::VerifyCheckoutSession.(current_user, params[:session_id])

    render json: {
      success: result[:success],
      payment_state: result[:payment_state]
    }
  rescue SecurityError => e
    Rails.logger.error("Security error verifying premium purchase: #{e.message}")
    Sentry.capture_exception(e, extra: { user_id: current_user.id })
    render json: { error: { type: "unauthorized" } }, status: :forbidden
  rescue StripeCheckoutSessionIncompleteError => e
    # Expected user-driven outcome (declined/abandoned payment), not a bug -
    # log only, don't report to Sentry.
    Rails.logger.info("Premium purchase checkout incomplete: #{e.decline_code || 'no reason given'}")
    render json: {
      error: {
        type: "checkout_payment_incomplete",
        decline_code: e.decline_code,
        currency: e.currency
      }
    }, status: :unprocessable_entity
  rescue ArgumentError => e
    Rails.logger.error("Invalid premium purchase session: #{e.message}")
    Sentry.capture_exception(e, extra: { user_id: current_user.id })
    render json: { error: { type: "invalid_session" } }, status: :unprocessable_entity
  rescue StandardError => e
    Rails.logger.error("Failed to verify premium purchase: #{e.message}")
    Sentry.capture_exception(e, extra: { user_id: current_user.id })
    render json: { error: { type: "verification_failed" } }, status: :internal_server_error
  end
end
