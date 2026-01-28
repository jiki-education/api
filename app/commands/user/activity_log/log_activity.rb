class User::ActivityLog::LogActivity
  include Mandate

  initialize_with :user, :date

  def call
    # Check via SQL if already logged - avoid loading full record
    return if already_logged?

    # Update via SQL
    User::ActivityData.where(user_id: user.id).update_all(
      ["activity_days = jsonb_set(activity_days, ?, ?), updated_at = ?",
       "{#{date_key}}", User::ActivityData::ACTIVITY_PRESENT.to_s, Time.current]
    )

    # Recalculate aggregates since value changed
    User::ActivityLog::UpdateAggregates.(user)
  end

  private
  def date_key = date.to_s

  def already_logged?
    User::ActivityData.where(user_id: user.id).
      where("activity_days->? = ?", date_key, User::ActivityData::ACTIVITY_PRESENT.to_s).
      exists?
  end
end
