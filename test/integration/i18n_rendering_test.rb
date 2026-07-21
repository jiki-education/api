require "test_helper"

# End-to-end checks that user-facing API messages resolve in Hungarian when the
# request runs in the hu locale, through the same render_error / render_success
# helpers and 422 validation path the frontend consumes.
class I18nRenderingTest < ActionDispatch::IntegrationTest
  # api_messages.* via render_success, locale from ?locale param
  test "render_success resolves api_messages in Hungarian" do
    post user_password_path,
      params: with_turnstile(user: { email: "someone@example.com" }, locale: "hu"),
      as: :json

    assert_response :success
    assert_equal(
      I18n.t("api_messages.password_reset_sent", email: "someone@example.com", locale: :hu),
      response.parsed_body["message"]
    )
  end

  # api_errors.* via render_error (render_403), locale from the signed-in user
  test "render_error resolves api_errors in Hungarian for a hu-locale user" do
    user = create(:user, locale: "hu")
    make_non_premium(user)
    sign_in_user(user)

    get internal_user_challenge_path(challenge_slug: "anything"), as: :json

    assert_response :forbidden
    assert_equal "premium_required", response.parsed_body.dig("error", "type")
    assert_equal(
      I18n.t("api_errors.premium_required", locale: :hu),
      response.parsed_body.dig("error", "message")
    )
  end

  # A 422 ActiveRecord validation error rendered in Hungarian: both the
  # top-level api_errors message and the errors.as_json field messages
  # (rails-i18n hu defaults) resolve in hu.
  test "422 validation error renders in Hungarian" do
    user = create(:user, locale: "hu")
    sign_in_user(user)

    patch email_internal_settings_path, params: { value: "not-an-email" }, as: :json

    assert_response :unprocessable_entity
    body = response.parsed_body
    assert_equal "email_update_failed", body.dig("error", "type")
    assert_equal I18n.t("api_errors.email_update_failed", locale: :hu), body.dig("error", "message")

    hu_invalid = I18n.with_locale(:hu) { I18n.t("errors.messages.invalid") }
    assert_equal [hu_invalid], body.dig("error", "errors", "email")
  end
end
