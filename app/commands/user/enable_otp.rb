class User
  class EnableOtp
    include Mandate

    initialize_with :user

    def call
      user.update!(otp_enabled_at: Time.current)
    end
  end
end
