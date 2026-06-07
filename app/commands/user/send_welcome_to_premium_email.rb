class User::SendWelcomeToPremiumEmail
  include Mandate

  initialize_with :user

  def call
    User::SendEmail.(user.data, kind: :welcome_to_premium) do
      PremiumMailer.welcome_to_premium(user).deliver_later
    end
  end
end
