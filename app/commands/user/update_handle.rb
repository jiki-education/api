class User
  class UpdateHandle
    include Mandate

    initialize_with :user, :new_handle

    def call
      user.update!(handle: new_handle)
    end
  end
end
