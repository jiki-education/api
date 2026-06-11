namespace :exercism do
  desc "Backfill premium entitlements for all Exercism-linked users (one-off)"
  task backfill_entitlements: :environment do
    User::Exercism::SyncEntitlements.()
    puts "Done."
  end
end
