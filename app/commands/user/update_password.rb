class User
  class UpdatePassword
    include Mandate

    initialize_with :user, :new_password

    def call
      user.update!(password: new_password, password_confirmation: new_password)
    end
  end
end
