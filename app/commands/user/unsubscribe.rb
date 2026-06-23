# Unsubscribes a user via their unsubscribe token (RFC 8058 one-click).
#
# With a valid preference key (e.g. "newsletters"), turns off just that
# preference. Without one, marks a full unsubscribe via email_complaint_at,
# which makes may_receive_emails? return false.
class User::Unsubscribe
  include Mandate

  initialize_with :token, key: nil

  def call
    raise InvalidUnsubscribeTokenError unless user&.data

    if specific_preference?
      User::UpdateNotificationPreference.(user, key, false)
    else
      user.data.update!(
        email_complaint_at: Time.current,
        email_complaint_type: 'unsubscribe_rfc_8058'
      )
    end

    user
  end

  private
  def specific_preference? = key.present? && User::Data.valid_notification_slug?(key)

  memoize
  def user = User.joins(:data).find_by(user_data: { unsubscribe_token: token })
end
