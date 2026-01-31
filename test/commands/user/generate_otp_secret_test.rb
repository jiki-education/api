require "test_helper"

class User::GenerateOtpSecretTest < ActiveSupport::TestCase
  test "generates OTP secret for user" do
    user = create(:user)
    assert_nil user.otp_secret

    User::GenerateOtpSecret.(user)

    user.reload
    assert user.otp_secret.present?
    assert_equal 32, user.otp_secret.length
  end

  test "does not replace existing OTP secret" do
    user = create(:user)
    User::GenerateOtpSecret.(user)
    old_secret = user.reload.otp_secret

    User::GenerateOtpSecret.(user)

    user.reload
    assert_equal old_secret, user.otp_secret
  end
end
