class User
  class VerifyOtp
    include Mandate

    initialize_with :user, :code

    def call
      return false unless user.otp_secret.present?

      totp = ROTP::TOTP.new(user.otp_secret, issuer: "Jiki")
      totp.verify(code, drift_behind: 30, drift_ahead: 30).present?
    end
  end
end
