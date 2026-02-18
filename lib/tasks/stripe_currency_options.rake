namespace :stripe do
  desc "Set currency_options on Stripe Price objects from PRICING constant"
  task set_currency_options: :environment do
    monthly_price_id = Jiki.config.stripe_premium_monthly_price_id
    annual_price_id = Jiki.config.stripe_premium_annual_price_id

    # Build currency_options from PRICING, excluding USD (the default currency)
    currency_options = {}
    PRICING.each do |currency, amounts|
      next if currency == :usd

      currency_options[currency] = {
        unit_amount: amounts[:monthly]
      }
    end

    puts "Updating monthly price #{monthly_price_id} with #{currency_options.size} currency options..."
    ::Stripe::Price.update(monthly_price_id, currency_options: currency_options)
    puts "Monthly price updated."

    # Build annual currency_options
    currency_options = {}
    PRICING.each do |currency, amounts|
      next if currency == :usd

      currency_options[currency] = {
        unit_amount: amounts[:annual]
      }
    end

    puts "Updating annual price #{annual_price_id} with #{currency_options.size} currency options..."
    ::Stripe::Price.update(annual_price_id, currency_options: currency_options)
    puts "Annual price updated."

    puts "Done! Currency options set for #{PRICING.size - 1} currencies."
  end
end
