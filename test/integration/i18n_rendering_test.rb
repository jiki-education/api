require "test_helper"

# End-to-end checks that error/success responses carry only a stable `type`
# (no localized `message`), while the parts of the response that are still
# genuinely locale-sensitive - ActiveRecord validation error text - continue
# to resolve in the request's locale.
class I18nRenderingTest < ActionDispatch::IntegrationTest
  test "render_success carries no message field" do
    post user_password_path,
      params: with_turnstile(user: { email: "someone@example.com" }, locale: "hu"),
      as: :json

    assert_response :success
    body = response.parsed_body
    assert_equal "password_reset_sent", body["type"]
    refute body.key?("message")
  end

  test "render_error carries no message field" do
    user = create(:user, locale: "hu")
    make_non_premium(user)
    sign_in_user(user)

    get internal_user_challenge_path(challenge_slug: "anything"), as: :json

    assert_response :forbidden
    body = response.parsed_body
    assert_equal "premium_required", body.dig("error", "type")
    refute body["error"].key?("message")
  end

  # A 422 ActiveRecord validation error: the top-level type is locale-independent,
  # but the errors.as_json field messages (rails-i18n hu defaults) still resolve in hu.
  test "422 validation error field messages render in Hungarian" do
    user = create(:user, locale: "hu")
    sign_in_user(user)

    patch email_internal_settings_path, params: { value: "not-an-email" }, as: :json

    assert_response :unprocessable_entity
    body = response.parsed_body
    assert_equal "email_update_failed", body.dig("error", "type")
    refute body["error"].key?("message")

    hu_invalid = I18n.with_locale(:hu) { I18n.t("errors.messages.invalid") }
    assert_equal [hu_invalid], body.dig("error", "errors", "email")
  end

  # An unsupported ?locale param must be ignored, not raise I18n::InvalidLocale
  test "unsupported locale param falls back to the user's locale without raising" do
    user = create(:user, locale: "hu")
    make_non_premium(user)
    sign_in_user(user)

    get "#{internal_user_challenge_path(challenge_slug: 'anything')}?locale=xx", as: :json

    assert_response :forbidden
    assert_equal "premium_required", response.parsed_body.dig("error", "type")
  end
end
