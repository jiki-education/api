# Unsubscribes a user from marketing emails via their unsubscribe token
#
# Sets email_complaint_at and email_complaint_type to mark the user as
# unsubscribed, which makes may_receive_emails? return false.
class User::Unsubscribe
  include Mandate

  initialize_with :token

  def call
    raise InvalidUnsubscribeTokenError unless user&.data

    user.data.update!(
      email_complaint_at: Time.current,
      email_complaint_type: 'unsubscribe_rfc_8058'
    )

    user
  end

  private
  memoize
  def user = User.joins(:data).find_by(user_data: { unsubscribe_token: token })
end
