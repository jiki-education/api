class Pricing::DeterminePrices
  include Mandate

  initialize_with :country_code

  # The single place that turns a country into Premium prices. Countries whose
  # currency has no price fall back to USD.
  def call
    {
      currency:,
      monthly: prices[:monthly],
      annual: prices[:annual],
      lifetime: low_usd? ? LOW_USD_LIFETIME_PRICE : prices[:lifetime],
      lifetime_price_id:
    }
  end

  private
  memoize
  def currency
    mapped = COUNTRY_CURRENCIES[country_code]&.to_sym
    PREMIUM_PRICES.key?(mapped) ? mapped : :usd
  end

  def prices = PREMIUM_PRICES[currency]

  def low_usd? = currency == :usd && LOW_USD_COUNTRIES.include?(country_code)

  def lifetime_price_id
    low_usd? ? Jiki.config.stripe_premium_lifetime_low_usd_price_id : Jiki.config.stripe_premium_lifetime_price_id
  end
end
