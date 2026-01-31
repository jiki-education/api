require "test_helper"

class User::VerifyOtpTest < ActiveSupport::TestCase
  test "returns true for valid OTP code" do
    user = create(:user)
    User::GenerateOtpSecret.(user)

    totp = ROTP::TOTP.new(user.otp_secret, issuer: "Jiki")
    valid_code = totp.now

    assert User::VerifyOtp.(user, valid_code)
  end

  test "returns false for invalid OTP code" do
    user = create(:user)
    User::GenerateOtpSecret.(user)

    refute User::VerifyOtp.(user, "000000")
  end

  test "returns false for user without OTP secret" do
    user = create(:user)
    assert_nil user.otp_secret

    refute User::VerifyOtp.(user, "123456")
  end

  test "allows drift of 30 seconds" do
    user = create(:user)
    User::GenerateOtpSecret.(user)

    totp = ROTP::TOTP.new(user.otp_secret, issuer: "Jiki")

    # Generate code from 25 seconds ago (within drift)
    travel_to(25.seconds.ago) do
      @old_code = totp.now
    end

    assert User::VerifyOtp.(user, @old_code)
  end

  test "rejects code outside drift window" do
    user = create(:user)
    User::GenerateOtpSecret.(user)

    totp = ROTP::TOTP.new(user.otp_secret, issuer: "Jiki")

    # Generate code from 60 seconds ago (outside drift)
    travel_to(60.seconds.ago) do
      @old_code = totp.now
    end

    refute User::VerifyOtp.(user, @old_code)
  end
end
