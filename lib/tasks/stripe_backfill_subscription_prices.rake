namespace :stripe do
  desc "Store each live subscription's amount and currency on user_data (one-off backfill)"
  task backfill_subscription_prices: :environment do
    scope = User::Data.where.not(stripe_subscription_id: nil).where(subscription_amount_in_cents: nil)
    puts "Backfilling #{scope.count} subscriptions"

    failures = 0
    scope.includes(:user).find_each do |data|
      subscription = ::Stripe::Subscription.retrieve(data.stripe_subscription_id)
      Stripe::SyncSubscriptionPrice.(data.user, subscription)
      print "."
    rescue StandardError => e
      failures += 1
      puts "\nUser #{data.user_id} (#{data.stripe_subscription_id}): #{e.class}: #{e.message}"
    end

    puts "\nDone. #{failures} failed."
  end
end
