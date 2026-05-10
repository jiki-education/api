class UserVideo < ApplicationRecord
  belongs_to :user

  validates :uuid, presence: true, uniqueness: { scope: :user_id }
  validates :watched_percentage, presence: true, inclusion: { in: 0..100 }

  scope :completed, -> { where.not(completed_at: nil) }
end
