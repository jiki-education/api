class CustomAuthFailure < Devise::FailureApp
  def respond
    self.status = 401
    self.content_type = "application/json"
    self.response_body = error_response.to_json

    # The controller's after_action :set_user_id_cookie never runs on Warden
    # failures because Warden bypasses the controller dispatch entirely. Clear
    # the cookie here so stale clients (and CloudFlare) stay in sync.
    response.delete_cookie(ApplicationController::USER_ID_COOKIE_NAME.to_s, domain: :all)
  end

  private
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
