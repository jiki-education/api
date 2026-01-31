class User
  class GenerateOtpSecret
    include Mandate

    initialize_with :user

    def call
      return if user.otp_secret.present?

      user.update!(otp_secret: ROTP::Base32.random)
    end
  end
end
