require "test_helper"

class User::DisableOtpTest < ActiveSupport::TestCase
  test "disables OTP for user" do
    user = create(:user)
    User::GenerateOtpSecret.(user)
    User::EnableOtp.(user)

    assert user.reload.otp_enabled?

    User::DisableOtp.(user)

    user.reload
    assert_nil user.otp_secret
    assert_nil user.otp_enabled_at
    refute user.otp_enabled?
  end

  test "is idempotent for user without OTP" do
    user = create(:user)
    refute user.otp_enabled?

    User::DisableOtp.(user)

    user.reload
    assert_nil user.otp_secret
    assert_nil user.otp_enabled_at
  end
end
