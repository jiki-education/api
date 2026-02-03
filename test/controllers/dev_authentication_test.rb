require "test_helper"

class DevAuthenticationTest < ActionDispatch::IntegrationTest
  include AuthenticationHelper

  setup do
    @user = create(:user)
    @course = create(:course)
  end

  test "URL-based authentication works in development environment" do
    Rails.env.stubs(:development?).returns(true)

    get internal_levels_path(course_slug: @course.slug, user_id: @user.id), as: :json

    assert_response :success
  end

  test "URL-based authentication is blocked in production environment" do
    Rails.env.stubs(:development?).returns(false)

    get internal_levels_path(course_slug: @course.slug, user_id: @user.id), as: :json

    assert_json_error(:unauthorized, error_type: :unauthenticated)
  end

  test "URL-based authentication is blocked in test environment" do
    # Test environment is the default (development? returns false)
    get internal_levels_path(course_slug: @course.slug, user_id: @user.id), as: :json

    assert_json_error(:unauthorized, error_type: :unauthenticated)
  end

  test "falls back to session authentication when no user_id param in development" do
    Rails.env.stubs(:development?).returns(true)

    sign_in_user(@user)
    get internal_levels_path(course_slug: @course.slug), as: :json

    assert_response :success
  end

  test "session authentication still works in development without user_id" do
    Rails.env.stubs(:development?).returns(true)

    sign_in_user(@user)
    get internal_levels_path(course_slug: @course.slug), as: :json

    assert_response :success
  end

  test "returns 401 when user_id is invalid in development" do
    Rails.env.stubs(:development?).returns(true)

    get internal_levels_path(course_slug: @course.slug, user_id: 99_999), as: :json

    assert_json_error(:unauthorized, error_type: :unauthenticated)
  end

  test "returns 401 in development when no authentication provided" do
    Rails.env.stubs(:development?).returns(true)

    get internal_levels_path(course_slug: @course.slug), as: :json

    assert_json_error(:unauthorized, error_type: :unauthenticated)
  end
end
