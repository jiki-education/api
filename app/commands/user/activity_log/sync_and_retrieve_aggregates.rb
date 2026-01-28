class User::ActivityLog::SyncAndRetrieveAggregates
  include Mandate

  initialize_with :user

  def call
    activity_data = user.activity_data
    return default_response unless activity_data

    # Fetch updated_at to determine if backfill is needed (in next phase)
    # For now, we just retrieve the values
    _updated_at = User::ActivityData.where(user_id: user.id).pick(:updated_at)

    {
      current_streak: activity_data.current_streak,
      total_active_days: activity_data.total_active_days
    }
  end

  private
  def default_response
    { current_streak: 0, total_active_days: 0 }
  end
end
