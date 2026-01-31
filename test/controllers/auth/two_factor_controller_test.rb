require "test_helper"

class Auth::TwoFactorControllerTest < ApplicationControllerTest
  setup do
    @admin = create(:user, :admin, email: "admin@example.com", password: "password123")
  end

  # Verify endpoint tests
  test "POST verify-2fa with valid OTP signs in user" do
    User::GenerateOtpSecret.(@admin)
    User::EnableOtp.(@admin)
    setup_otp_session(@admin)

    otp_code = generate_valid_otp(@admin)

    post auth_verify_2fa_path, params: { otp_code: otp_code }, as: :json

    assert_response :ok

    json = response.parsed_body
    assert_equal @admin.handle, json["user"]["handle"]

    # Verify user IS signed in
    get internal_me_path, as: :json
    assert_response :ok
  end

  test "POST verify-2fa with invalid OTP returns error" do
    User::GenerateOtpSecret.(@admin)
    User::EnableOtp.(@admin)
    setup_otp_session(@admin)

    post auth_verify_2fa_path, params: { otp_code: "000000" }, as: :json

    assert_response :unauthorized

    json = response.parsed_body
    assert_equal "invalid_otp", json["error"]["type"]

    # Verify user is NOT signed in
    get internal_me_path, as: :json
    assert_response :unauthorized
  end

  test "POST verify-2fa without session returns session_expired" do
    User::GenerateOtpSecret.(@admin)
    User::EnableOtp.(@admin)

    otp_code = generate_valid_otp(@admin)

    post auth_verify_2fa_path, params: { otp_code: otp_code }, as: :json

    assert_response :unauthorized

    json = response.parsed_body
    assert_equal "session_expired", json["error"]["type"]
  end

  test "POST verify-2fa with expired session returns session_expired" do
    User::GenerateOtpSecret.(@admin)
    User::EnableOtp.(@admin)
    setup_otp_session(@admin, timestamp: 10.minutes.ago)

    otp_code = generate_valid_otp(@admin)

    post auth_verify_2fa_path, params: { otp_code: otp_code }, as: :json

    assert_response :unauthorized

    json = response.parsed_body
    assert_equal "session_expired", json["error"]["type"]
  end

  # Setup endpoint tests
  test "POST setup-2fa with valid OTP enables 2FA and signs in user" do
    # Login will generate a new OTP secret, so we don't pre-generate one
    setup_otp_session(@admin)

    # Reload to get the OTP secret that was generated during login
    @admin.reload
    refute @admin.otp_enabled?
    assert @admin.otp_secret.present?

    otp_code = generate_valid_otp(@admin)

    post auth_setup_2fa_path, params: { otp_code: otp_code }, as: :json

    assert_response :ok

    json = response.parsed_body
    assert_equal @admin.handle, json["user"]["handle"]

    # Verify 2FA is now enabled
    @admin.reload
    assert @admin.otp_enabled?

    # Verify user IS signed in
    get internal_me_path, as: :json
    assert_response :ok
  end

  test "POST setup-2fa with invalid OTP returns error" do
    # Login will generate OTP secret
    setup_otp_session(@admin)

    post auth_setup_2fa_path, params: { otp_code: "000000" }, as: :json

    assert_response :unauthorized

    json = response.parsed_body
    assert_equal "invalid_otp", json["error"]["type"]

    # Verify 2FA is NOT enabled
    @admin.reload
    refute @admin.otp_enabled?
  end

  test "POST setup-2fa without session returns session_expired" do
    User::GenerateOtpSecret.(@admin)

    otp_code = generate_valid_otp(@admin)

    post auth_setup_2fa_path, params: { otp_code: otp_code }, as: :json

    assert_response :unauthorized

    json = response.parsed_body
    assert_equal "session_expired", json["error"]["type"]
  end

  private
  def setup_otp_session(user, timestamp: Time.current)
    # Simulate the session state that would be set by the login controller
    # In integration tests, we need to set this via a login request
    post user_session_path, params: {
      user: {
        email: user.email,
        password: "password123"
      }
    }, as: :json

    # If we need to test expired sessions, we manipulate the session directly
    return unless timestamp != Time.current

    # For expired session tests, we need to use a different approach
    # since we can't easily manipulate sessions in controller tests
    # Instead, we'll travel in time
    travel_to(timestamp) do
      post user_session_path, params: {
        user: {
          email: user.email,
          password: "password123"
        }
      }, as: :json
    end
  end

  def generate_valid_otp(user)
    totp = ROTP::TOTP.new(user.otp_secret, issuer: "Jiki")
    totp.now
  end
end
