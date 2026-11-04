class External::PricingController < ApplicationController
  def show
    country = request.headers["CF-IPCountry"].to_s.upcase[0, 2].presence
    prices = Pricing::DeterminePrices.(country)

    render json: {
      premium_prices: {
        currency: prices[:currency],
        monthly: prices[:monthly],
        annual: prices[:annual],
        lifetime: prices[:lifetime],
        country_code: country
      }
    }
  end
end
