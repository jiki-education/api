class External::PricingController < ApplicationController
  def show
    country = request.headers["CF-IPCountry"].to_s.upcase[0, 2]
    currency = COUNTRY_CURRENCIES[country]&.to_sym
    currency = :usd unless PREMIUM_PRICES.key?(currency)
    prices = PREMIUM_PRICES[currency]

    render json: {
      premium_prices: {
        currency:,
        monthly: prices[:monthly],
        annual: prices[:annual],
        country_code: country.presence
      }
    }
  end
end
