class User::DetermineCurrency
  include Mandate

  initialize_with :user

  def call
    return "usd" if user.data.country_code.blank?

    currency = COUNTRY_CURRENCIES[user.data.country_code]
    return "usd" if currency.blank?

    PRICING.key?(currency.to_sym) ? currency : "usd"
  end
end
