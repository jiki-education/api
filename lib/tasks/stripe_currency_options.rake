namespace :stripe do
  desc "Set currency_options on Stripe Price objects from PREMIUM_PRICES constant (only adds missing currencies)"
  task set_currency_options: :environment do
    monthly_price_id = Jiki.config.stripe_premium_monthly_price_id
    annual_price_id = Jiki.config.stripe_premium_annual_price_id

    monthly_price = ::Stripe::Price.retrieve({ id: monthly_price_id, expand: ["currency_options"] })
    annual_price = ::Stripe::Price.retrieve({ id: annual_price_id, expand: ["currency_options"] })

    existing_monthly = monthly_price.currency_options.map(&:first).map(&:to_sym).to_set
    existing_annual = annual_price.currency_options.map(&:first).map(&:to_sym).to_set

    # Build monthly currency_options for currencies not yet on the price
    monthly_options = {}
    PREMIUM_PRICES.each do |currency, amounts|
      next if currency == :usd || existing_monthly.include?(currency)

      monthly_options[currency] = { unit_amount: amounts[:monthly] }
    end

    if monthly_options.any?
      puts "Adding #{monthly_options.size} new monthly currency options: #{monthly_options.keys.join(', ')}"
      ::Stripe::Price.update(monthly_price_id, currency_options: monthly_options)
      puts "Monthly price updated."
    else
      puts "No new monthly currencies to add."
    end

    # Build annual currency_options for currencies not yet on the price
    annual_options = {}
    PREMIUM_PRICES.each do |currency, amounts|
      next if currency == :usd || existing_annual.include?(currency)

      annual_options[currency] = { unit_amount: amounts[:annual] }
    end

    if annual_options.any?
      puts "Adding #{annual_options.size} new annual currency options: #{annual_options.keys.join(', ')}"
      ::Stripe::Price.update(annual_price_id, currency_options: annual_options)
      puts "Annual price updated."
    else
      puts "No new annual currencies to add."
    end

    puts "Done!"
  end
end
