require "test_helper"

class Auth::DiscourseControllerTest < ApplicationControllerTest
  setup do
    @user = create(:user, email: "test@example.com", password: "password123", name: "Test User")
    @secret = "test_discourse_secret_key_12345678901234567890"

    # Define the method if it doesn't exist (for test environment before config is updated)
    Jiki.secrets.define_singleton_method(:discourse_sso_secret) { nil } unless Jiki.secrets.respond_to?(:discourse_sso_secret)
  end

  test "GET sso redirects unauthenticated user to frontend login with return_to param" do
    Jiki.config.stubs(:frontend_base_url).returns("https://app.jiki.io")

    sso_payload = build_sso_payload(nonce: "test_nonce_123")

    get auth_discourse_sso_path, params: { sso: sso_payload[:sso], sig: sso_payload[:sig] }

    assert_response :redirect

    redirect_uri = URI.parse(response.location)
    assert_equal "app.jiki.io", redirect_uri.host
    assert_equal "/auth/login", redirect_uri.path

    return_to = CGI.parse(redirect_uri.query)["return_to"].first
    assert_includes return_to, "auth/discourse/sso"
    assert_includes return_to, "sso="
    assert_includes return_to, "sig="
  end

  test "GET sso redirects authenticated user to Discourse with signed payload" do
    Jiki.secrets.stubs(:discourse_sso_secret).returns(@secret)

    sign_in_user(@user)

    nonce = "test_nonce_456"
    sso_payload = build_sso_payload(nonce: nonce)

    get auth_discourse_sso_path, params: { sso: sso_payload[:sso], sig: sso_payload[:sig] }

    assert_response :redirect
    assert_includes response.location, "forum.jiki.io/session/sso_login"

    # Parse the redirect URL to verify the payload
    redirect_uri = URI.parse(response.location)
    query_params = CGI.parse(redirect_uri.query)

    response_sso = query_params["sso"].first
    response_sig = query_params["sig"].first

    # Verify signature is valid
    expected_sig = OpenSSL::HMAC.hexdigest("SHA256", @secret, response_sso)
    assert_equal expected_sig, response_sig

    # Decode and verify payload contents
    decoded_payload = CGI.parse(Base64.decode64(response_sso))
    assert_equal @user.email, decoded_payload["email"].first
    assert_equal @user.name, decoded_payload["name"].first
    assert_equal @user.handle, decoded_payload["username"].first
    assert_equal @user.id.to_s, decoded_payload["external_id"].first
    assert_equal nonce, decoded_payload["nonce"].first
  end

  test "GET sso preserves original SSO params in return_to URL for unauthenticated users" do
    Jiki.config.stubs(:frontend_base_url).returns("https://app.jiki.io")

    nonce = "preserve_nonce_789"
    sso_payload = build_sso_payload(nonce: nonce)

    get auth_discourse_sso_path, params: { sso: sso_payload[:sso], sig: sso_payload[:sig] }

    assert_response :redirect

    redirect_uri = URI.parse(response.location)
    return_to = CGI.parse(redirect_uri.query)["return_to"].first
    return_to_uri = URI.parse(return_to)
    return_to_params = CGI.parse(return_to_uri.query)

    # Verify the original SSO params are preserved
    assert_equal sso_payload[:sso], return_to_params["sso"].first
    assert_equal sso_payload[:sig], return_to_params["sig"].first
  end

  private
  def build_sso_payload(nonce:, return_sso_url: "https://forum.jiki.io/session/sso_login")
    raw_payload = "nonce=#{nonce}&return_sso_url=#{CGI.escape(return_sso_url)}"
    sso = Base64.strict_encode64(raw_payload)
    sig = OpenSSL::HMAC.hexdigest("SHA256", @secret, sso)

    { sso: sso, sig: sig }
  end
end
