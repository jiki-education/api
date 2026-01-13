class User
  class UpdateEmail
    include Mandate

    initialize_with :user, :new_email

    def call
      user.update!(email: new_email, email_verified: false)
    end
  end
end
