require "test_helper"

class DevAuthenticationTest < ActionDispatch::IntegrationTest
  include AuthenticationHelper

  setup do
    @user = create(:user)
  end

  test "URL-based authentication works in development environment" do
    Rails.env.stubs(:development?).returns(true)

    get "#{internal_levels_path}?user_id=#{@user.id}", as: :json

    assert_response :success
  end

  test "URL-based authentication is blocked in production environment" do
    Rails.env.stubs(:development?).returns(false)

    get "#{internal_levels_path}?user_id=#{@user.id}", as: :json

    assert_response :unauthorized
    assert_equal "unauthorized", response.parsed_body["error"]["type"]
  end

  test "URL-based authentication is blocked in test environment" do
    # Test environment is the default (development? returns false)
    get "#{internal_levels_path}?user_id=#{@user.id}", as: :json

    assert_response :unauthorized
    assert_equal "unauthorized", response.parsed_body["error"]["type"]
  end

  test "falls back to JWT authentication when no user_id param in development" do
    Rails.env.stubs(:development?).returns(true)

    headers = auth_headers_for(@user)
    get internal_levels_path, headers: headers, as: :json

    assert_response :success
  end

  test "JWT authentication still works in development without user_id" do
    Rails.env.stubs(:development?).returns(true)

    headers = auth_headers_for(@user)
    get internal_levels_path, headers: headers, as: :json

    assert_response :success
  end

  test "returns 401 when user_id is invalid in development" do
    Rails.env.stubs(:development?).returns(true)

    get "#{internal_levels_path}?user_id=99999", as: :json

    assert_response :unauthorized
    assert_equal "unauthorized", response.parsed_body["error"]["type"]
  end

  test "returns 401 in development when no authentication provided" do
    Rails.env.stubs(:development?).returns(true)

    get internal_levels_path, as: :json

    assert_response :unauthorized
    assert_equal "unauthorized", response.parsed_body["error"]["type"]
  end
end
