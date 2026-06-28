class BackfillUnlockedConcepts < ActiveRecord::Migration[8.1]
  # Concepts used to be unlocked via a has_one association, so a lesson that
  # taught more than one concept only ever unlocked a single (arbitrary) one.
  # Now that a lesson can unlock many concepts, retroactively unlock every
  # concept whose unlocking lesson the user has already completed.
  #
  # Unlocks are append-only and the unlock event only fires at completion time,
  # so affected users (who completed the lesson before the fix) stay broken
  # without this backfill.
  def up
    execute(<<~SQL.squish)
      UPDATE user_data
      SET unlocked_concept_ids = sub.concept_ids
      FROM (
        SELECT
          ud.id AS user_data_id,
          ARRAY(
            SELECT DISTINCT unnest(ud.unlocked_concept_ids || array_agg(c.id))
          ) AS concept_ids
        FROM user_data ud
        JOIN users u ON u.id = ud.user_id
        JOIN user_lessons ul ON ul.user_id = u.id AND ul.completed_at IS NOT NULL
        JOIN concepts c ON c.unlocked_by_lesson_id = ul.lesson_id
        GROUP BY ud.id
      ) AS sub
      WHERE user_data.id = sub.user_data_id
        AND user_data.unlocked_concept_ids IS DISTINCT FROM sub.concept_ids
    SQL
  end

  def down
    # Unlocks are append-only and we can't distinguish backfilled rows from
    # genuine ones, so there's nothing safe to reverse.
  end
end
