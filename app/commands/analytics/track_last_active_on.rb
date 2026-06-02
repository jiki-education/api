class Analytics::TrackLastActiveOn
  include Mandate

  initialize_with :user

  def call
    # Cheap in-memory guard - this runs on every authenticated request.
    return if user.last_active_on == Date.current
    return unless claim_today!

    Analytics::TrackEvent.defer(user, "site_visited")
  end

  private
  # Concurrent requests can both pass the in-memory check above, so claim
  # today atomically in SQL. Only the request that actually flips the column
  # sends the event.
  def claim_today!
    User::Data.where(user_id: user.id).
      where("last_active_on IS NULL OR last_active_on < ?", Date.current).
      update_all(last_active_on: Date.current, updated_at: Time.current).
      positive?
  end
end
