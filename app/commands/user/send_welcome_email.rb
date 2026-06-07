class User::SendWelcomeEmail
  include Mandate

  initialize_with :user

  def call
    User::SendEmail.(user.data, kind: :welcome) do
      AccountMailer.welcome(user).deliver_later
    end
  end
end
