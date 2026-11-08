class Stripe::DetermineDeclineCode
  include Mandate

  # Stripe's own English message text is never returned to the client - only the
  # stable decline_code/code, so the front-end can map it to localized copy (see
  # https://docs.stripe.com/declines/codes). A handful of codes are collapsed to
  # the generic "card_declined" per Stripe's own guidance: don't tell a customer
  # their card was reported fraudulent/stolen/lost, since that tips off an
  # attacker who's testing stolen numbers to try a different card instead.
  SENSITIVE_DECLINE_CODES = %w[fraudulent stolen_card lost_card merchant_blacklist pickup_card restricted_card].freeze

  initialize_with :payment_intent

  def call
    return nil if code.blank?

    SENSITIVE_DECLINE_CODES.include?(code) ? "card_declined" : code
  end

  private
  memoize
  def code
    error = payment_intent&.last_payment_error
    return nil unless error

    error.decline_code.presence || error.code
  end
end
