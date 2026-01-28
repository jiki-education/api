class User::ActivityData < ApplicationRecord
  belongs_to :user

  # Activity day values
  NO_ACTIVITY = 1
  ACTIVITY_PRESENT = 2
  STREAK_FREEZE_USED = 3
end
