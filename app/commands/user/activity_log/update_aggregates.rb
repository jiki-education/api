class User::ActivityLog::UpdateAggregates
  include Mandate

  initialize_with :user

  def call
    activity_data = user.activity_data
    return unless activity_data

    activity_data.current_streak = calculate_current_streak
    activity_data.longest_streak = [calculate_longest_streak, activity_data.longest_streak].max
    activity_data.total_active_days = calculate_total_active_days

    activity_data.save! if activity_data.changed?
  end

  private
  def activity_data = user.activity_data

  memoize
  def today
    Time.current.in_time_zone(activity_data.effective_timezone).to_date
  end

  memoize
  def sorted_dates
    activity_data.activity_days.keys.map(&:to_date).sort.reverse
  end

  def calculate_current_streak
    return 0 if sorted_dates.empty?

    streak = 0
    expected_date = today

    # Allow starting from yesterday if no activity today
    expected_date = today - 1.day unless activity_data.active_on?(today)

    sorted_dates.each do |date|
      break if date < expected_date # Gap found

      if date == expected_date && activity_data.active_on?(date)
        streak += 1
        expected_date = date - 1.day
      elsif date > expected_date
        # Skip future dates or dates we've passed
        next
      else
        break
      end
    end

    streak
  end

  def calculate_longest_streak
    return 0 if sorted_dates.empty?

    max_streak = 0
    current_streak = 0
    previous_date = nil

    sorted_dates.reverse_each do |date|
      if activity_data.active_on?(date)
        if previous_date.nil? || date == previous_date + 1.day
          current_streak += 1
        else
          max_streak = [max_streak, current_streak].max
          current_streak = 1
        end
      else
        max_streak = [max_streak, current_streak].max
        current_streak = 0
      end
      previous_date = date
    end

    [max_streak, current_streak].max
  end

  def calculate_total_active_days
    activity_data.activity_days.count { |_, v| v == User::ActivityData::ACTIVITY_PRESENT }
  end
end
