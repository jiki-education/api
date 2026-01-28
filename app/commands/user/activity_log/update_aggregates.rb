class User::ActivityLog::UpdateAggregates
  include Mandate

  initialize_with :user

  def call
    User::ActivityData.connection.execute(
      User::ActivityData.sanitize_sql([
                                        <<~SQL.squish,
                                          WITH dates AS (
                                            SELECT
                                              MAX(key::date) FILTER (WHERE value IN (:activity_present, :streak_freeze)) AS most_recent_active,
                                              MAX(key::date) FILTER (WHERE value = :no_activity) AS last_break,
                                              MIN(key::date) AS first_active,
                                              COUNT(*) FILTER (WHERE value = :activity_present) AS total_active
                                            FROM user_activity_data, jsonb_each_text(activity_days)
                                            WHERE user_id = :user_id
                                          ),
                                          calcs AS (
                                            SELECT
                                              CASE
                                                WHEN most_recent_active IS NULL OR most_recent_active < :yesterday THEN 0
                                                ELSE GREATEST(0, most_recent_active - COALESCE(last_break, first_active - 1))
                                              END AS new_streak,
                                              total_active
                                            FROM dates
                                          )
                                          UPDATE user_activity_data
                                          SET
                                            current_streak = calcs.new_streak,
                                            longest_streak = GREATEST(longest_streak, calcs.new_streak),
                                            total_active_days = calcs.total_active,
                                            updated_at = :now
                                          FROM calcs
                                          WHERE user_id = :user_id
                                        SQL
                                        {
                                          yesterday:,
                                          activity_present: User::ActivityData::ACTIVITY_PRESENT.to_s,
                                          streak_freeze: User::ActivityData::STREAK_FREEZE_USED.to_s,
                                          no_activity: User::ActivityData::NO_ACTIVITY.to_s,
                                          now: Time.current,
                                          user_id: user.id
                                        }
                                      ])
    )
  end

  private
  memoize
  def yesterday = Time.current.in_time_zone(user.timezone).to_date - 1.day
end
