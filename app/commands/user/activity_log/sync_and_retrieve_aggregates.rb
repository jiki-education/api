class User::ActivityLog::SyncAndRetrieveAggregates
  include Mandate

  initialize_with :user

  def call
    data = fetch_activity_data!
    return data if data[:last_date] && data[:last_date] >= yesterday

    User::ActivityLog::Backfill.(user)
    fetch_activity_data!
  end

  private
  def fetch_activity_data!
    sql = <<~SQL.squish
      SELECT
        current_streak,
        total_active_days,
        (SELECT MAX(key::date) FROM jsonb_each_text(activity_days)) AS last_date
      FROM user_activity_data
      WHERE user_id = :user_id
    SQL

    User::ActivityData.connection.select_one(
      User::ActivityData.sanitize_sql([sql, { user_id: user.id }])
    ).then do |result|
      {
        current_streak: result['current_streak'],
        total_active_days: result['total_active_days'],
        last_date: result['last_date']&.to_date
      }
    end
  end

  memoize
  def yesterday = Time.current.in_time_zone(user.timezone).to_date - 1.day
end
