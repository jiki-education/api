class User::Mailshot < ApplicationRecord
  include Emailable
  has_email_status # default `email_status` column

  belongs_to :user
  belongs_to :mailshot

  # mail_to_user performs the real preference check, so SendEmail's pref key stays nil...
  def email_communication_preferences_key(_kind = nil) = nil

  # ...but email_should_send? mirrors that check so the status is marked `skipped`
  # accurately when the user has opted out of this mailshot's preference.
  def email_should_send?(_kind = nil)
    user.public_send("receive_#{mailshot.email_communication_preferences_key}?")
  end
end
