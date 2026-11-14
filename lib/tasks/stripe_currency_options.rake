namespace :stripe do
  desc "Sync currency_options on Stripe Price objects from PREMIUM_PRICES (adds missing currencies, and corrects changed lifetime amounts)"
  task set_currency_options: :environment do
    price_ids = {
      monthly: Jiki.config.stripe_premium_monthly_price_id,
      annual: Jiki.config.stripe_premium_annual_price_id,
      lifetime: Jiki.config.stripe_premium_lifetime_price_id
    }

    price_ids.each do |key, price_id|
      price = ::Stripe::Price.retrieve({ id: price_id, expand: ["currency_options"] })
      existing = price.currency_options.to_h { |currency, option| [currency.to_sym, option.unit_amount] }

      # Monthly and annual are legacy, so only lifetime amounts get corrected.
      options = {}
      PREMIUM_PRICES.each do |currency, amounts|
        next if currency == :usd

        amount = amounts[key]
        next if existing[currency] == amount
        next if existing.key?(currency) && key != :lifetime

        puts "#{key} #{currency}: #{existing[currency] || 'missing'} -> #{amount}"
        options[currency] = { unit_amount: amount }
      end

      if options.any?
        ::Stripe::Price.update(price_id, currency_options: options)
        puts "#{key.to_s.capitalize} price updated (#{options.size} currencies)."
      else
        puts "No #{key} currencies to change."
      end
    end

    puts "Done!"
  end
end
