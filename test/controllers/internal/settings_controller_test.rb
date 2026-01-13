require "test_helper"

class Internal::SettingsControllerTest < ApplicationControllerTest
  setup do
    @user = create(:user, name: "Test User", email: "test@example.com", locale: "en", password: "password123")
    @headers = auth_headers_for(@user)
  end

  # Auth guards
  guard_incorrect_token! :internal_settings_path, method: :get
  guard_incorrect_token! :name_internal_settings_path, method: :patch
  guard_incorrect_token! :email_internal_settings_path, method: :patch
  guard_incorrect_token! :password_internal_settings_path, method: :patch
  guard_incorrect_token! :locale_internal_settings_path, method: :patch
  guard_incorrect_token! :handle_internal_settings_path, method: :patch
  guard_incorrect_token! :notification_internal_settings_path, args: ["product_updates"], method: :patch

  # Show tests
  test "GET show returns current settings" do
    get internal_settings_path, headers: @headers, as: :json

    assert_response :success
    assert_json_response({
      settings: SerializeSettings.(@user)
    })
  end

  # Name tests
  test "PATCH name updates successfully" do
    patch name_internal_settings_path, params: { value: "New Name" }, headers: @headers, as: :json

    assert_response :success
    assert_equal "New Name", @user.reload.name

    json = response.parsed_body
    assert_equal "New Name", json["settings"]["name"]
  end

  # Email tests
  test "PATCH email stores in unconfirmed_email with correct sudo_password" do
    patch email_internal_settings_path,
      params: { value: "new@example.com", sudo_password: "password123" },
      headers: @headers,
      as: :json

    assert_response :success
    @user.reload
    # With reconfirmable, new email goes to unconfirmed_email
    assert_equal "test@example.com", @user.email
    assert_equal "new@example.com", @user.unconfirmed_email
  end

  test "PATCH email fails with incorrect sudo_password" do
    patch email_internal_settings_path,
      params: { value: "new@example.com", sudo_password: "wrongpassword" },
      headers: @headers,
      as: :json

    assert_response :unauthorized

    json = response.parsed_body
    assert_equal "invalid_password", json["error"]["type"]
    assert_equal "test@example.com", @user.reload.email
  end

  test "PATCH email fails with missing sudo_password" do
    patch email_internal_settings_path,
      params: { value: "new@example.com" },
      headers: @headers,
      as: :json

    assert_response :unauthorized
    assert_equal "test@example.com", @user.reload.email
  end

  # Password tests
  test "PATCH password updates with correct sudo_password" do
    patch password_internal_settings_path,
      params: { value: "newpassword456", sudo_password: "password123" },
      headers: @headers,
      as: :json

    assert_response :success
    assert @user.reload.valid_password?("newpassword456")
  end

  test "PATCH password fails with incorrect sudo_password" do
    patch password_internal_settings_path,
      params: { value: "newpassword456", sudo_password: "wrongpassword" },
      headers: @headers,
      as: :json

    assert_response :unauthorized
    assert @user.reload.valid_password?("password123")
  end

  test "PATCH password fails with missing sudo_password" do
    patch password_internal_settings_path,
      params: { value: "newpassword456" },
      headers: @headers,
      as: :json

    assert_response :unauthorized
    assert @user.reload.valid_password?("password123")
  end

  # Locale tests
  test "PATCH locale updates successfully" do
    patch locale_internal_settings_path, params: { value: "hu" }, headers: @headers, as: :json

    assert_response :success
    assert_equal "hu", @user.reload.locale
  end

  test "PATCH locale fails with invalid locale" do
    patch locale_internal_settings_path, params: { value: "invalid" }, headers: @headers, as: :json

    assert_response :unprocessable_entity

    json = response.parsed_body
    assert_equal "validation_error", json["error"]["type"]
    assert_equal "en", @user.reload.locale
  end

  # Handle tests
  test "PATCH handle updates successfully" do
    patch handle_internal_settings_path, params: { value: "new-handle" }, headers: @headers, as: :json

    assert_response :success
    assert_equal "new-handle", @user.reload.handle
  end

  test "PATCH handle fails with duplicate" do
    create(:user, handle: "taken-handle")

    patch handle_internal_settings_path, params: { value: "taken-handle" }, headers: @headers, as: :json

    assert_response :unprocessable_entity

    json = response.parsed_body
    assert_equal "validation_error", json["error"]["type"]
  end

  # Notification tests
  test "PATCH notification updates preference successfully" do
    patch notification_internal_settings_path("product_updates"),
      params: { value: false },
      headers: @headers,
      as: :json

    assert_response :success
    refute @user.data.reload.receive_product_updates
  end

  test "PATCH notification returns 404 for invalid slug" do
    patch notification_internal_settings_path("invalid_slug"),
      params: { value: false },
      headers: @headers,
      as: :json

    assert_response :not_found

    json = response.parsed_body
    assert_equal "not_found", json["error"]["type"]
    assert_equal "Unknown notification type", json["error"]["message"]
  end
end
