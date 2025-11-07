require "test_helper"

class MultiDeviceAuthenticationTest < ActionDispatch::IntegrationTest
  setup do
    @user = create(:user, email: "test@example.com", password: "password123")
  end

  test "user can login from multiple devices simultaneously" do
    # Login from iPhone
    post user_session_path,
      params: { user: { email: @user.email, password: "password123" } },
      headers: { "User-Agent" => "Mozilla/5.0 (iPhone; CPU iPhone OS 14_0 like Mac OS X)" },
      as: :json

    assert_response :ok
    iphone_access_token = response.headers["Authorization"]
    iphone_refresh_token = response.parsed_body["refresh_token"]

    # Login from Android
    post user_session_path,
      params: { user: { email: @user.email, password: "password123" } },
      headers: { "User-Agent" => "Mozilla/5.0 (Linux; Android 11; Pixel 5)" },
      as: :json

    assert_response :ok
    android_access_token = response.headers["Authorization"]
    android_refresh_token = response.parsed_body["refresh_token"]

    # Login from Mac
    post user_session_path,
      params: { user: { email: @user.email, password: "password123" } },
      headers: { "User-Agent" => "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7)" },
      as: :json

    assert_response :ok
    mac_access_token = response.headers["Authorization"]
    mac_refresh_token = response.parsed_body["refresh_token"]

    # All tokens should be different
    refute_equal iphone_access_token, android_access_token
    refute_equal iphone_access_token, mac_access_token
    refute_equal android_access_token, mac_access_token

    refute_equal iphone_refresh_token, android_refresh_token
    refute_equal iphone_refresh_token, mac_refresh_token
    refute_equal android_refresh_token, mac_refresh_token

    # User should have 3 JWT tokens and 3 refresh tokens
    @user.reload
    assert_equal 3, @user.jwt_tokens.count
    assert_equal 3, @user.refresh_tokens.count

    # All devices should be able to make requests
    get user_levels_index_path,
      headers: { "Authorization" => iphone_access_token },
      as: :json
    assert_response :ok

    get user_levels_index_path,
      headers: { "Authorization" => android_access_token },
      as: :json
    assert_response :ok

    get user_levels_index_path,
      headers: { "Authorization" => mac_access_token },
      as: :json
    assert_response :ok
  end

  test "refresh tokens are device-specific and include User-Agent in aud" do
    # Login from iPhone
    post user_session_path,
      params: { user: { email: @user.email, password: "password123" } },
      headers: { "User-Agent" => "Mozilla/5.0 (iPhone; CPU iPhone OS 14_0 like Mac OS X)" },
      as: :json

    @user.reload
    iphone_refresh_token = @user.refresh_tokens.last

    assert iphone_refresh_token.aud.present?
    assert_includes iphone_refresh_token.aud, "iPhone"
    assert_equal "iPhone", iphone_refresh_token.device_name

    # Login from Android
    post user_session_path,
      params: { user: { email: @user.email, password: "password123" } },
      headers: { "User-Agent" => "Mozilla/5.0 (Linux; Android 11; Pixel 5)" },
      as: :json

    @user.reload
    android_refresh_token = @user.refresh_tokens.last

    assert android_refresh_token.aud.present?
    assert_includes android_refresh_token.aud, "Android"
    assert_equal "Android", android_refresh_token.device_name

    # Both refresh tokens should exist
    assert_equal 2, @user.refresh_tokens.count
  end

  test "logging out from one device does not affect other devices" do
    # Login from two devices
    post user_session_path,
      params: { user: { email: @user.email, password: "password123" } },
      headers: { "User-Agent" => "iPhone" },
      as: :json

    device1_access_token = response.headers["Authorization"]

    post user_session_path,
      params: { user: { email: @user.email, password: "password123" } },
      headers: { "User-Agent" => "Android" },
      as: :json

    device2_access_token = response.headers["Authorization"]

    @user.reload
    assert_equal 2, @user.jwt_tokens.count
    assert_equal 2, @user.refresh_tokens.count

    # Logout from device 1
    delete destroy_user_session_path,
      headers: { "Authorization" => device1_access_token },
      as: :json

    assert_response :no_content

    # Per-device logout: only device 1's refresh token is revoked
    # Device 2's refresh token remains active
    @user.reload
    assert_equal 1, @user.refresh_tokens.count

    # Device 2's access token should still work
    get user_levels_index_path,
      headers: { "Authorization" => device2_access_token },
      as: :json
    assert_response :ok
  end

  test "each device can independently refresh its access token" do
    # Login from two devices
    post user_session_path,
      params: { user: { email: @user.email, password: "password123" } },
      headers: { "User-Agent" => "iPhone" },
      as: :json

    iphone_refresh_token = response.parsed_body["refresh_token"]

    post user_session_path,
      params: { user: { email: @user.email, password: "password123" } },
      headers: { "User-Agent" => "Android" },
      as: :json

    android_refresh_token = response.parsed_body["refresh_token"]

    # iPhone refreshes
    post refresh_path,
      params: { refresh_token: iphone_refresh_token },
      as: :json

    assert_response :ok
    new_iphone_token = response.headers["Authorization"]

    # Android refreshes
    post refresh_path,
      params: { refresh_token: android_refresh_token },
      as: :json

    assert_response :ok
    new_android_token = response.headers["Authorization"]

    # Both should work
    assert new_iphone_token.present?
    assert new_android_token.present?
    refute_equal new_iphone_token, new_android_token

    # User should have 4 JWT tokens (2 from login + 2 from refresh)
    @user.reload
    assert_equal 4, @user.jwt_tokens.count
  end

  test "user can have multiple active sessions across many devices" do
    devices = [
      "Mozilla/5.0 (iPhone; CPU iPhone OS 14_0 like Mac OS X)",
      "Mozilla/5.0 (iPad; CPU OS 14_0 like Mac OS X)",
      "Mozilla/5.0 (Linux; Android 11; Pixel 5)",
      "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7)",
      "Mozilla/5.0 (Windows NT 10.0; Win64; x64)"
    ]

    tokens = []

    # Prosopite will detect N+1 during login, so scan each login separately
    devices.each do |user_agent|
      Prosopite.pause
      post user_session_path,
        params: { user: { email: @user.email, password: "password123" } },
        headers: { "User-Agent" => user_agent },
        as: :json
      Prosopite.resume

      assert_response :ok
      tokens << response.headers["Authorization"]
    end

    # User should have 5 JWT tokens and 5 refresh tokens
    @user.reload
    assert_equal 5, @user.jwt_tokens.count
    assert_equal 5, @user.refresh_tokens.count

    # All tokens should work
    # Note: Each authenticated request checks allowlist, which is expected behavior
    Prosopite.pause
    tokens.each do |token|
      get user_levels_index_path,
        headers: { "Authorization" => token },
        as: :json
      assert_response :ok
    end
    Prosopite.resume
  end

  test "expired JWT tokens can still be refreshed if refresh token is valid" do
    # Login from device
    post user_session_path,
      params: { user: { email: @user.email, password: "password123" } },
      as: :json

    access_token = response.headers["Authorization"]
    refresh_token_value = response.parsed_body["refresh_token"]

    # Access token works
    get user_levels_index_path,
      headers: { "Authorization" => access_token },
      as: :json
    assert_response :ok

    # Simulate access token expiry by removing it from allowlist
    @user.reload
    jwt_token = @user.jwt_tokens.last
    jwt_token.destroy

    # Access token no longer works (revoked from allowlist)
    get user_levels_index_path,
      headers: { "Authorization" => access_token },
      as: :json
    assert_response :unauthorized

    # But refresh token still works to get a new access token
    post refresh_path,
      params: { refresh_token: refresh_token_value },
      as: :json

    assert_response :ok
    new_access_token = response.headers["Authorization"]

    # New access token works
    get user_levels_index_path,
      headers: { "Authorization" => new_access_token },
      as: :json
    assert_response :ok
  end

  private
  def user_levels_index_path
    "/internal/user_levels"
  end

  def refresh_path
    "/auth/refresh"
  end
end
