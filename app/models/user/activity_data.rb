class User::ActivityData < ApplicationRecord
  belongs_to :user

  # Activity day values
  NO_ACTIVITY = 1
  ACTIVITY_PRESENT = 2
  STREAK_FREEZE_USED = 3

  def activity_for(date) = activity_days[date.to_s]

  def active_on?(date)
    value = activity_for(date)
    value == ACTIVITY_PRESENT || value == STREAK_FREEZE_USED
  end
end
