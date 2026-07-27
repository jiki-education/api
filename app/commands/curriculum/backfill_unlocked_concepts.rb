# Retroactively unlock every concept whose unlocking lesson a user has already
# completed.
#
# Concept unlocks are persisted (User::Data#unlocked_concept_ids) and the unlock
# event only fires at lesson-completion time. So whenever a concept is added, or
# re-pointed to a different unlocking lesson, users who completed that lesson
# *before* the change never receive it. This reconciles them, and is run from
# db:seed so the seeded concept set always stays consistent with user progress.
#
# Idempotent and non-destructive: unlocks are append-only (each user's existing
# ids are preserved via the union), the resulting array is sorted so re-runs
# produce byte-identical values, and a row is only rewritten when its set of
# unlocked concept ids actually changes.
#
# Runs as a single set-based SQL statement so it scales to the whole user base
# without loading records. Does NOT emit :concept_unlocked events - there is no
# request/event context during seeding - matching the original backfill migration.
class Curriculum::BackfillUnlockedConcepts
  include Mandate

  # Returns the number of user_data rows that were updated.
  def call
    ActiveRecord::Base.connection.exec_update(sql)
  end

  private
  def sql
    <<~SQL.squish
      UPDATE user_data
      SET unlocked_concept_ids = sub.concept_ids
      FROM (
        SELECT
          ud.id AS user_data_id,
          ARRAY(
            SELECT DISTINCT unnest(ud.unlocked_concept_ids || array_agg(c.id)) AS concept_id
            ORDER BY concept_id
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
end
