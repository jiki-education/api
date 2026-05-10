class CustomAuthFailure < Devise::FailureApp
  def respond
    # The controller's after_action :set_user_id_cookie never runs on Warden
    # failures because Warden bypasses the controller dispatch entirely. Clear
    # the cookie here so stale clients (and CloudFlare) stay in sync.
    delete_user_id_cookie!

    self.status = 401
    self.content_type = "application/json"
    self.response_body = error_response.to_json
  end

  private
  # Mirrors what `ActionDispatch::Cookies` does for `domain: :all` so the
  # browser actually accepts our deletion header. Rack's delete_cookie has no
  # special handling for `:all` and would emit the literal string "all".
  def delete_user_id_cookie!
    options = { path: "/" }
    cookie_domain = resolve_cookie_domain
    options[:domain] = cookie_domain if cookie_domain
    response.delete_cookie(ApplicationController::USER_ID_COOKIE_NAME.to_s, options)
  end

  def resolve_cookie_domain
    host = request.host
    parts = host.split(".", -1)
    return nil if host.match?(/\A[\d.]+\z/) || parts.include?("") || parts.length == 1

    parts.last(2).join(".")
  end

  def error_response
    if warden_message == :unconfirmed
      { error: { type: "unconfirmed", message: I18n.t("api_errors.unconfirmed"), email: attempted_email } }
    else
      { error: { type: "unauthenticated", message: I18n.t("api_errors.unauthenticated") } }
    end
  end

  def attempted_email
    # Extract email from login params
    params.dig(:user, :email)
  end
end
