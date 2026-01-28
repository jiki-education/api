class SerializeProfile
  include Mandate

  initialize_with :user

  def call
    {
      icon: "flag",
      avatar_url: "https://randomuser.me/api/portraits/men/19.jpg",
      streaks_enabled: user.data.streaks_enabled,
      **streak_data
    }
  end

  private
  def streak_data
    if user.data.streaks_enabled
      { current_streak: aggregates[:current_streak] }
    else
      { total_active_days: aggregates[:total_active_days] }
    end
  end

  memoize
  def aggregates = User::ActivityLog::SyncAndRetrieveAggregates.(user)
end
