# Recovers historical bonus passes for exercises whose bonus is purely a
# lines-of-code target, by re-scoring each user's most recent submission.
# See Curriculum::BackfillLocBonuses for what's in scope and what isn't.
class BackfillLocBonuses < ActiveRecord::Migration[8.0]
  def up
    Curriculum::BackfillLocBonuses.()
  end

  def down
    # We can't distinguish a backfilled bonus from one recorded live, so
    # there's nothing safe to reverse.
  end
end
