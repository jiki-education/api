module TurnstileVerifiable
  extend ActiveSupport::Concern

  private
  def verify_turnstile!
    return render_403(:invalid_captcha) if params[:cf_turnstile_response].blank?
    return if Captcha::VerifyTurnstileToken.(params[:cf_turnstile_response], remote_ip: turnstile_remote_ip)

    render_403(:invalid_captcha)
  end

  def turnstile_remote_ip
    request.headers["CF-Connecting-IP"].presence || request.remote_ip
  end
end
