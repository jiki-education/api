class Pricing::DetermineLifetimePrice
  include Mandate

  initialize_with :country_code, :currency

  def call
    if low_usd?
      { amount_in_cents: LOW_USD_LIFETIME_PRICE, stripe_price_id: Jiki.config.stripe_premium_lifetime_low_usd_price_id }
    else
      { amount_in_cents: PREMIUM_PRICES[currency][:lifetime], stripe_price_id: Jiki.config.stripe_premium_lifetime_price_id }
    end
  end

  private
  def low_usd? = currency.to_sym == :usd && LOW_USD_COUNTRIES.include?(country_code)
end
