require "test_helper"

class Internal::Settings::HandlesControllerTest < ApplicationControllerTest
  setup do
    @user = create(:user, handle: "old-handle")
    @headers = auth_headers_for(@user)
  end

  guard_incorrect_token! :internal_settings_handle_path, method: :patch

  test "PATCH update changes user handle successfully" do
    patch internal_settings_handle_path, params: { user: { handle: "new-handle" } }, headers: @headers, as: :json

    assert_response :success

    json = response.parsed_body
    assert_equal "new-handle", json["user"]["handle"]
    assert_equal "new-handle", @user.reload.handle
  end

  test "PATCH update returns validation error for duplicate handle" do
    create(:user, handle: "taken-handle")

    patch internal_settings_handle_path, params: { user: { handle: "taken-handle" } }, headers: @headers, as: :json

    assert_response :unprocessable_entity

    json = response.parsed_body
    assert_equal "validation_error", json["error"]["type"]
    assert_equal "Handle update failed", json["error"]["message"]
    assert json["error"]["errors"]["handle"].present?

    # Verify handle wasn't changed
    assert_equal "old-handle", @user.reload.handle
  end

  test "PATCH update returns validation error for blank handle" do
    patch internal_settings_handle_path, params: { user: { handle: "" } }, headers: @headers, as: :json

    assert_response :unprocessable_entity

    json = response.parsed_body
    assert_equal "validation_error", json["error"]["type"]
    assert json["error"]["errors"]["handle"].present?

    # Verify handle wasn't changed
    assert_equal "old-handle", @user.reload.handle
  end
end
