class User::UpgradeToPremium
  include Mandate

  initialize_with :user

  def call
    user.with_lock do
      return if user.data.premium? || user.data.max?

      user.data.update!(membership_type: 'premium')
    end

    send_welcome_email!
  end

  private
  def send_welcome_email!
    PremiumMailer.welcome_to_premium(user).deliver_later
  end
end
