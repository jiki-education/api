require "test_helper"

class User::EnableOtpTest < ActiveSupport::TestCase
  test "enables OTP for user with secret" do
    user = create(:user)
    User::GenerateOtpSecret.(user)

    assert_nil user.reload.otp_enabled_at

    User::EnableOtp.(user)

    user.reload
    assert user.otp_enabled_at.present?
    assert user.otp_enabled?
  end

  test "sets otp_enabled_at to current time" do
    user = create(:user)
    User::GenerateOtpSecret.(user)

    freeze_time do
      User::EnableOtp.(user)
      assert_equal Time.current, user.reload.otp_enabled_at
    end
  end
end
