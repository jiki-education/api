class User::RefreshToken < ApplicationRecord
  self.table_name = "user_refresh_tokens"

  belongs_to :user

  # Virtual attribute for the plain text token (never stored in DB)
  attr_accessor :token

  validates :expires_at, presence: true
  validates :crypted_token, uniqueness: true, allow_nil: true

  # Scopes
  scope :expired, -> { where("expires_at < ?", Time.current) }
  scope :active, -> { where("expires_at >= ?", Time.current) }

  # Generate a new refresh token before validation (so it's available for uniqueness check)
  before_validation :generate_token, on: :create

  # Find a refresh token by its plain text token
  # This hashes the input and looks up the crypted version
  def self.find_by_token(plain_token)
    crypted = Digest::SHA256.hexdigest(plain_token)
    find_by(crypted_token: crypted)
  end

  # Check if this refresh token has expired
  def expired?
    expires_at < Time.current
  end

  def device_name
    return "Unknown Device" if aud.blank?

    case aud
    when /iPhone/i then "iPhone"
    when /iPad/i then "iPad"
    when /Android/i then "Android"
    when /Windows/i then "Windows PC"
    when /Macintosh/i then "Mac"
    when /Linux/i then "Linux"
    when /Chrome/i then "Chrome Browser"
    when /Firefox/i then "Firefox Browser"
    when /Safari/i then "Safari Browser"
    when /Edge/i then "Edge Browser"
    else
      aud.truncate(50)
    end
  end

  private
  # Generate a random token and store its SHA256 hash
  # The plain text token is stored in the virtual @token attribute
  # and returned to the caller (to send to the frontend)
  def generate_token
    self.token = SecureRandom.hex(32) # 64 character hex string
    self.crypted_token = Digest::SHA256.hexdigest(token)
  end
end
