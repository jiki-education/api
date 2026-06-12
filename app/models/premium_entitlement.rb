class PremiumEntitlement < ApplicationRecord
  EXERCISM_INSIDER = "exercism_insider".freeze
  EXERCISM_BOOTCAMP = "exercism_bootcamp".freeze
  STRIPE = "stripe".freeze

  belongs_to :user, class_name: "::User"

  scope :active, lambda {
    where(revoked_at: nil).where("expires_at IS NULL OR expires_at > ?", Time.current)
  }

  def active? = revoked_at.nil? && (expires_at.nil? || expires_at > Time.current)
end
