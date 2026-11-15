namespace :stripe do
  desc "Add missing currencies from PREMIUM_PRICES to the Stripe Price objects' currency_options"
  task set_currency_options: :environment do
    price_ids = {
      monthly: Jiki.config.stripe_premium_monthly_price_id,
      annual: Jiki.config.stripe_premium_annual_price_id,
      lifetime: Jiki.config.stripe_premium_lifetime_price_id
    }

    price_ids.each do |key, price_id|
      price = ::Stripe::Price.retrieve({ id: price_id, expand: ["currency_options"] })
      existing = price.currency_options.to_h { |currency, option| [currency.to_sym, option.unit_amount] }

      options = {}
      PREMIUM_PRICES.each do |currency, amounts|
        next if currency == :usd || existing.key?(currency)

        options[currency] = { unit_amount: amounts[key] }
      end

      changed = PREMIUM_PRICES.select { |currency, amounts| existing.key?(currency) && existing[currency] != amounts[key] }
      if changed.any?
        puts "#{key}: #{changed.size} amounts differ from PREMIUM_PRICES, which Stripe can't change on an existing Price."
        puts "Run stripe:create_lifetime_price to replace the lifetime Price." if key == :lifetime
      end

      if options.any?
        puts "Adding #{options.size} new #{key} currency options: #{options.keys.join(', ')}"
        ::Stripe::Price.update(price_id, currency_options: options)
      else
        puts "No new #{key} currencies to add."
      end
    end

    puts "Done!"
  end

  # Stripe can't change an existing currency option's amount, so repricing
  # lifetime means a new Price. Set the printed ID as
  # stripe_premium_lifetime_price_id in the config.
  desc "Create a new lifetime Stripe Price with every amount from PREMIUM_PRICES"
  task create_lifetime_price: :environment do
    current = ::Stripe::Price.retrieve(Jiki.config.stripe_premium_lifetime_price_id)

    price = ::Stripe::Price.create(
      product: current.product,
      currency: "usd",
      unit_amount: PREMIUM_PRICES[:usd][:lifetime],
      tax_behavior: current.tax_behavior,
      nickname: current.nickname,
      currency_options: PREMIUM_PRICES.except(:usd).transform_values { |amounts| { unit_amount: amounts[:lifetime] } }
    )

    puts "Created #{price.id} with #{PREMIUM_PRICES.size} currencies."
    puts "Set stripe_premium_lifetime_price_id to #{price.id}."
  end
end
