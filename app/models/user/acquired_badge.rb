class User::AcquiredBadge < ApplicationRecord
  belongs_to :user
  belongs_to :badge, counter_cache: :num_awardees

  scope :unrevealed, -> { where(revealed: false) }
  scope :revealed, -> { where(revealed: true) }

  delegate :name, :icon, :description, :secret, to: :badge
end
