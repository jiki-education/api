class Payment < ApplicationRecord
  belongs_to :user

  validates :payment_processor_id, presence: true
  validates :amount_in_cents, presence: true, numericality: { greater_than: 0 }
  validates :currency, presence: true
  validates :product, presence: true, inclusion: { in: %w[premium max] }

  scope :most_recent_first, -> { order(created_at: :desc) }
end
