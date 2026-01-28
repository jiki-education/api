class User::ActivityLog::Backfill
  include Mandate

  initialize_with :user

  def call
    result = User::ActivityData.connection.execute(
      User::ActivityData.sanitize_sql(
        [
          sql,
          {
            user_id: user.id,
            yesterday:,
            no_activity: User::ActivityData::NO_ACTIVITY.to_s,
            now: Time.current
          }
        ]
      )
    )

    User::ActivityLog::UpdateAggregates.(user) if result.ntuples.positive?
  end

  private
  def sql
    <<~SQL.squish
      WITH last_recorded AS (
        SELECT MAX(key::date) AS last_date
        FROM user_activity_data, jsonb_each_text(activity_days)
        WHERE user_id = :user_id
      ),
      missing_dates AS (
        SELECT d::date::text AS date_key
        FROM last_recorded, generate_series(
          last_recorded.last_date + 1,
          :yesterday,
          '1 day'::interval
        ) AS d
        WHERE last_recorded.last_date IS NOT NULL
          AND NOT EXISTS (
            SELECT 1 FROM user_activity_data, jsonb_each_text(activity_days) AS existing
            WHERE user_activity_data.user_id = :user_id AND existing.key = d::date::text
          )
      ),
      new_entries AS (
        SELECT COALESCE(jsonb_object_agg(date_key, :no_activity::int), '{}'::jsonb) AS entries
        FROM missing_dates
      )
      UPDATE user_activity_data
      SET activity_days = activity_days || new_entries.entries,
          updated_at = :now
      FROM new_entries
      WHERE user_id = :user_id
        AND new_entries.entries != '{}'::jsonb
      RETURNING 1
    SQL
  end

  memoize
  def yesterday
    Time.current.in_time_zone(user.timezone).to_date - 1.day
  end
end
