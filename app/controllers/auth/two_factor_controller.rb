class Auth::TwoFactorController < ApplicationController
  include Devise::Controllers::Helpers

  OTP_SESSION_TIMEOUT = 5.minutes

  before_action :use_user!
  before_action :validate_otp_session

  def verify
    if User::VerifyOtp.(@user, params[:otp_code])
      complete_sign_in
    else
      render_invalid_otp
    end
  end

  def setup
    if User::VerifyOtp.(@user, params[:otp_code])
      User::EnableOtp.(@user)
      complete_sign_in
    else
      render_invalid_otp
    end
  end

  private
  def validate_otp_session
    return render_session_expired unless session[:otp_user_id]
    return render_session_expired if otp_session_expired?

    render_session_expired unless @user
  end

  def otp_session_expired?
    return true unless session[:otp_timestamp]

    Time.current - Time.zone.at(session[:otp_timestamp]) > OTP_SESSION_TIMEOUT
  end

  def use_user!
    @user = User.find_by(id: session[:otp_user_id])
  end

  def complete_sign_in
    clear_otp_session
    sign_in(:user, @user)
    render json: { status: "success", user: SerializeUser.(@user) }, status: :ok
  end

  def clear_otp_session
    session.delete(:otp_user_id)
    session.delete(:otp_timestamp)
  end

  def render_session_expired
    clear_otp_session
    render_401(:session_expired)
  end

  def render_invalid_otp
    render_401(:invalid_otp)
  end
end
