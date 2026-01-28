class User::ActivityLog::LogActivity
  include Mandate

  initialize_with :user, :date

  def call
    activity_data = user.activity_data || user.create_activity_data!
    date_key = date.to_s

    # Only update if value changed
    return if activity_data.activity_days[date_key] == User::ActivityData::ACTIVITY_PRESENT

    activity_data.activity_days[date_key] = User::ActivityData::ACTIVITY_PRESENT

    # Update last_active_date if this date is newer
    activity_data.last_active_date = date if activity_data.last_active_date.nil? || date > activity_data.last_active_date

    activity_data.save!

    # Recalculate aggregates since value changed
    User::ActivityLog::UpdateAggregates.(user)
  end
end
