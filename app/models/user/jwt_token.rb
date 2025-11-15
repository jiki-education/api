class User::JwtToken < ApplicationRecord
  self.table_name = "user_jwt_tokens"

  belongs_to :user
  belongs_to :refresh_token, class_name: "User::RefreshToken", optional: true

  validates :jti, presence: true, uniqueness: true
  validates :expires_at, presence: true

  # Clean up expired tokens
  scope :expired, -> { where("expires_at < ?", Time.current) }
  scope :active, -> { where("expires_at >= ?", Time.current) }

  # Check if token is expired
  def expired?
    expires_at < Time.current
  end
end
