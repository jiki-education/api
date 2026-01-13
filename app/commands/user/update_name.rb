class User
  class UpdateName
    include Mandate

    initialize_with :user, :new_name

    def call
      user.update!(name: new_name)
    end
  end
end
