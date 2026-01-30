require "test_helper"

class Internal::SettingsControllerTest < ApplicationControllerTest
  setup do
    @user = create(:user, name: "Test User", email: "test@example.com", locale: "en", password: "password123")
    sign_in_user(@user)
  end

  # Auth guards
  guard_incorrect_token! :internal_settings_path, method: :get
  guard_incorrect_token! :name_internal_settings_path, method: :patch
  guard_incorrect_token! :email_internal_settings_path, method: :patch
  guard_incorrect_token! :password_internal_settings_path, method: :patch
  guard_incorrect_token! :locale_internal_settings_path, method: :patch
  guard_incorrect_token! :handle_internal_settings_path, method: :patch
  guard_incorrect_token! :notification_internal_settings_path, args: ["product_updates"], method: :patch
  guard_incorrect_token! :streaks_internal_settings_path, method: :patch

  # Show tests
  test "GET show returns current settings" do
    get internal_settings_path, as: :json

    assert_response :success
    assert_json_response({
      settings: SerializeSettings.(@user)
    })
  end

  # Name tests
  test "PATCH name updates successfully" do
    patch name_internal_settings_path, params: { value: "New Name" }, as: :json

    assert_response :success
    assert_equal "New Name", @user.reload.name

    json = response.parsed_body
    assert_equal "New Name", json["settings"]["name"]
  end

  # Email tests
  test "PATCH email stores in unconfirmed_email" do
    patch email_internal_settings_path,
      params: { value: "new@example.com" },
      as: :json

    assert_response :success
    @user.reload
    # With reconfirmable, new email goes to unconfirmed_email
    assert_equal "test@example.com", @user.email
    assert_equal "new@example.com", @user.unconfirmed_email
  end

  # TODO: Re-enable once frontend supports sudo password verification
  test "PATCH email fails with incorrect sudo_password" do
    skip "Re-enable once frontend supports sudo password verification"

    patch email_internal_settings_path,
      params: { value: "new@example.com", sudo_password: "wrongpassword" },
      as: :json

    assert_response :unauthorized

    json = response.parsed_body
    assert_equal "invalid_password", json["error"]["type"]
    assert_equal "test@example.com", @user.reload.email
  end

  # TODO: Re-enable once frontend supports sudo password verification
  test "PATCH email fails with missing sudo_password" do
    skip "Re-enable once frontend supports sudo password verification"

    patch email_internal_settings_path,
      params: { value: "new@example.com" },
      as: :json

    assert_response :unauthorized
    assert_equal "test@example.com", @user.reload.email
  end

  # Password tests
  test "PATCH password updates successfully" do
    patch password_internal_settings_path,
      params: { value: "newpassword456" },
      as: :json

    assert_response :success
    assert @user.reload.valid_password?("newpassword456")
  end

  # TODO: Re-enable once frontend supports sudo password verification
  test "PATCH password fails with incorrect sudo_password" do
    skip "Re-enable once frontend supports sudo password verification"

    patch password_internal_settings_path,
      params: { value: "newpassword456", sudo_password: "wrongpassword" },
      as: :json

    assert_response :unauthorized
    assert @user.reload.valid_password?("password123")
  end

  # TODO: Re-enable once frontend supports sudo password verification
  test "PATCH password fails with missing sudo_password" do
    skip "Re-enable once frontend supports sudo password verification"

    patch password_internal_settings_path,
      params: { value: "newpassword456" },
      as: :json

    assert_response :unauthorized
    assert @user.reload.valid_password?("password123")
  end

  # Locale tests
  test "PATCH locale updates successfully" do
    patch locale_internal_settings_path, params: { value: "hu" }, as: :json

    assert_response :success
    assert_equal "hu", @user.reload.locale
  end

  test "PATCH locale fails with invalid locale" do
    patch locale_internal_settings_path, params: { value: "invalid" }, as: :json

    assert_response :unprocessable_entity

    json = response.parsed_body
    assert_equal "validation_error", json["error"]["type"]
    assert_equal "en", @user.reload.locale
  end

  # Handle tests
  test "PATCH handle updates successfully" do
    patch handle_internal_settings_path, params: { value: "new-handle" }, as: :json

    assert_response :success
    assert_equal "new-handle", @user.reload.handle
  end

  test "PATCH handle fails with duplicate" do
    create(:user, handle: "taken-handle")

    patch handle_internal_settings_path, params: { value: "taken-handle" }, as: :json

    assert_response :unprocessable_entity

    json = response.parsed_body
    assert_equal "validation_error", json["error"]["type"]
  end

  # Notification tests
  test "PATCH notification updates preference successfully" do
    patch notification_internal_settings_path("newsletters"),
      params: { value: false },
      as: :json

    assert_response :success
    refute @user.data.reload.receive_newsletters
  end

  test "PATCH notification returns 404 for invalid slug" do
    patch notification_internal_settings_path("invalid_slug"),
      params: { value: false },
      as: :json

    assert_response :not_found

    json = response.parsed_body
    assert_equal "not_found", json["error"]["type"]
    assert_equal "Unknown notification type", json["error"]["message"]
  end

  # Streaks tests
  test "PATCH streaks enables streaks" do
    refute @user.data.streaks_enabled

    patch streaks_internal_settings_path, params: { enabled: true }, as: :json

    assert_response :success
    assert @user.data.reload.streaks_enabled

    json = response.parsed_body
    assert json["settings"]["streaks_enabled"]
  end

  test "PATCH streaks disables streaks" do
    @user.data.update!(streaks_enabled: true)

    patch streaks_internal_settings_path, params: { enabled: false }, as: :json

    assert_response :success
    refute @user.data.reload.streaks_enabled

    json = response.parsed_body
    refute json["settings"]["streaks_enabled"]
  end
end
