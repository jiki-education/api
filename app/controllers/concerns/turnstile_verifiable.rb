module TurnstileVerifiable
  extend ActiveSupport::Concern

  private
  def verify_turnstile!
    return render_403(:invalid_captcha) if params[:cf_turnstile_response].blank?
    return if Captcha::VerifyTurnstileToken.(params[:cf_turnstile_response], remote_ip: Current.user_ip)

    render_403(:invalid_captcha)
  end
end
