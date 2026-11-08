namespace :stripe do
  desc "Set currency_options on Stripe Price objects from PREMIUM_PRICES constant (only adds missing currencies)"
  task set_currency_options: :environment do
    price_ids = {
      monthly: Jiki.config.stripe_premium_monthly_price_id,
      annual: Jiki.config.stripe_premium_annual_price_id,
      lifetime: Jiki.config.stripe_premium_lifetime_price_id
    }

    price_ids.each do |key, price_id|
      price = ::Stripe::Price.retrieve({ id: price_id, expand: ["currency_options"] })
      existing = price.currency_options.map(&:first).map(&:to_sym).to_set

      # Build currency_options for currencies not yet on the price
      options = {}
      PREMIUM_PRICES.each do |currency, amounts|
        next if currency == :usd || existing.include?(currency)

        options[currency] = { unit_amount: amounts[key] }
      end

      if options.any?
        puts "Adding #{options.size} new #{key} currency options: #{options.keys.join(', ')}"
        ::Stripe::Price.update(price_id, currency_options: options)
        puts "#{key.to_s.capitalize} price updated."
      else
        puts "No new #{key} currencies to add."
      end
    end

    puts "Done!"
  end
end
