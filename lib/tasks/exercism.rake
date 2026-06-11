namespace :exercism do
  desc "Backfill premium entitlements for all Exercism-linked users (one-off)"
  task backfill_entitlements: :environment do
    User::Exercism::SyncEntitlementsJob.perform_now
    puts "Done."
  end
end
