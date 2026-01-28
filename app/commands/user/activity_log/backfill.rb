class User::ActivityLog::Backfill
  include Mandate

  initialize_with :user

  def call
    activity_data = user.activity_data
    return unless activity_data

    last_recorded_date = find_last_recorded_date
    return unless last_recorded_date

    # Fill all days between last recorded day and today (excluding today)
    (last_recorded_date + 1.day..yesterday).each do |date|
      date_key = date.to_s
      next if activity_data.activity_days.key?(date_key)

      # For now, fill with NO_ACTIVITY (value 1)
      # TODO: Logic for streak freeze (value 3) TBD
      activity_data.activity_days[date_key] = User::ActivityData::NO_ACTIVITY
    end

    activity_data.save! if activity_data.changed?

    User::ActivityLog::UpdateAggregates.(user)
  end

  private
  def activity_data = user.activity_data

  memoize
  def yesterday
    Time.current.in_time_zone(activity_data.effective_timezone).to_date - 1.day
  end

  def find_last_recorded_date
    return nil if activity_data.activity_days.empty?

    activity_data.activity_days.keys.map(&:to_date).max
  end
end
