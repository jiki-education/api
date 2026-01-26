class Auth::DiscourseController < ApplicationController
  FORUM_URL = "https://forum.jiki.io".freeze

  def sso
    unless user_signed_in?
      frontend_login_url = "#{Jiki.config.frontend_base_url}/auth/login"
      return_url = request.original_url
      redirect_to "#{frontend_login_url}?return_to=#{CGI.escape(return_url)}", allow_other_host: true
      return
    end

    secret = Jiki.secrets.discourse_sso_secret

    sso = DiscourseApi::SingleSignOn.parse(request.query_string, secret)
    sso.email = current_user.email
    sso.name = current_user.name
    sso.username = current_user.handle
    sso.external_id = current_user.id
    sso.sso_secret = secret

    redirect_to sso.to_url("#{FORUM_URL}/session/sso_login"), allow_other_host: true
  end
end
