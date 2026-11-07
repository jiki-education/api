class Payment < ApplicationRecord
  belongs_to :user

  validates :payment_processor_id, presence: true
  validates :amount_in_cents, presence: true, numericality: { greater_than: 0 }
  validates :currency, presence: true
  validates :product, presence: true, inclusion: { in: %w[premium] }

  scope :most_recent_first, -> { order(created_at: :desc) }

  # One-off purchases store their type in data. Subscription invoices predate
  # the field, so anything without it is a subscription payment.
  def purchase_type = data["purchase_type"] || "subscription"

  # "refunded" or "disputed" once a lifetime purchase has been revoked.
  def revoked_reason = data["revoked_reason"]
end
