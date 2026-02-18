class SerializeUser
  include Mandate

  initialize_with :user

  def call
    {
      handle: user.handle,
      membership_type: user.data.membership_type,
      email: user.email,
      name: user.name,
      provider: user.provider,
      email_confirmed: user.confirmed?,
      subscription_status: user.data.subscription_status,
      subscription: subscription_data,
      premium_prices: premium_prices_data
    }
  end

  private
  memoize
  def currency = User::DetermineCurrency.(user)

  def premium_prices_data
    prices = PRICING[currency.to_sym]
    {
      currency: currency,
      monthly: prices[:monthly],
      annual: prices[:annual],
      country_code: user.data.country_code
    }
  end

  def subscription_data
    # Include subscription details when there's an active/pending subscription state
    return nil if %w[never_subscribed canceled].include?(user.data.subscription_status)

    {
      interval: user.data.subscription_interval,
      in_grace_period: user.data.in_grace_period?,
      grace_period_ends_at: user.data.grace_period_ends_at,
      subscription_valid_until: user.data.subscription_valid_until
    }
  end
end
