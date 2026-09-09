# Recovers historical bonus passes for exercises whose bonus is purely a
# lines-of-code target, by re-scoring each user's most recent submission.
# See Migrations::BackfillLocBonuses for what's in scope and what isn't.
class BackfillLocBonuses < ActiveRecord::Migration[8.0]
  def up
    # Deferred rather than run inline: this downloads the latest submission's
    # files for every completed lesson in scope, so its runtime scales with
    # usage and grows between now and whenever this deploys. Migrations run in
    # the entrypoint before the container serves, so doing it here would hold
    # the new ECS task un-healthy for the duration.
    Migrations::BackfillLocBonuses.defer
  end

  def down
    # We can't distinguish a backfilled bonus from one recorded live, so
    # there's nothing safe to reverse.
  end
end
