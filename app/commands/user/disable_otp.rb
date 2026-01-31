class User
  class DisableOtp
    include Mandate

    initialize_with :user

    def call
      user.update!(otp_secret: nil, otp_enabled_at: nil)
    end
  end
end
