require "test_helper"

class Auth::LogoutAllControllerTest < ApplicationControllerTest
  setup do
    @user = create(:user, email: "test@example.com", password: "password123")
  end

  test "DELETE destroy revokes tokens for ALL devices" do
    # Simulate three devices logging in
    devices = [
      { name: "Desktop Chrome", ua: "Mozilla/5.0 (Windows NT 10.0) Chrome/91.0" },
      { name: "Mobile Safari", ua: "Mozilla/5.0 (iPhone) Safari/14.0" },
      { name: "Tablet Firefox", ua: "Mozilla/5.0 (Android) Firefox/89.0" }
    ]

    # Pause Prosopite to avoid false positive N+1 from sequential login requests
    tokens = Prosopite.pause do
      devices.map do |device|
        post user_session_path,
          params: {
            user: {
              email: "test@example.com",
              password: "password123"
            }
          },
          headers: { "User-Agent" => device[:ua] },
          as: :json

        response.headers["Authorization"]
      end
    end

    @user.reload
    assert_equal 3, @user.refresh_tokens.count
    assert_equal 3, @user.jwt_tokens.count

    # Logout from ALL devices using the first device's token
    delete auth_logout_all_path,
      headers: {
        "Authorization" => tokens.first,
        "User-Agent" => devices.first[:ua]
      },
      as: :json

    assert_response :no_content

    @user.reload
    # ALL tokens should be revoked
    assert_equal 0, @user.refresh_tokens.count
    assert_equal 0, @user.jwt_tokens.count

    # None of the access tokens should work anymore
    # Pause Prosopite to avoid false positive N+1 from checking each token individually
    Prosopite.pause do
      tokens.each_with_index do |token, index|
        get internal_me_path,
          headers: {
            "Authorization" => token,
            "User-Agent" => devices[index][:ua]
          },
          as: :json

        assert_response :unauthorized
      end
    end
  end

  test "DELETE destroy without token returns error" do
    delete auth_logout_all_path, as: :json

    assert_response :unauthorized

    json = response.parsed_body
    assert_equal "unauthorized", json["error"]["type"]
  end
end
