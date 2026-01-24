class User::UpgradeToMax
  include Mandate

  initialize_with :user

  def call
    user.with_lock do
      return if user.data.max?

      user.data.update!(membership_type: 'max')
    end

    send_welcome_email!
  end

  private
  def send_welcome_email!
    UserMailer.welcome_to_max(user).deliver_later
  end
end
