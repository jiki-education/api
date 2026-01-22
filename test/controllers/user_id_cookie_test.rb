require "test_helper"

class UserIdCookieTest < ApplicationControllerTest
  setup do
    @user = create(:user, email: "test@example.com", password: "password123")
  end

  test "cookie is set when user logs in" do
    post user_session_path, params: {
      user: { email: "test@example.com", password: "password123" }
    }, as: :json

    assert_response :ok
    assert_cookie_set
  end

  test "cookie is cleared when user logs out" do
    # Login first
    post user_session_path, params: {
      user: { email: "test@example.com", password: "password123" }
    }, as: :json
    assert_response :ok
    assert_cookie_set

    # Capture the domain from the set cookie
    set_cookie = jiki_user_id_cookie
    set_domain = set_cookie[/domain=([^;]+)/, 1]

    # Logout
    delete destroy_user_session_path, as: :json
    assert_response :no_content

    # Cookie should be cleared with matching domain
    delete_cookie = jiki_user_id_cookie
    assert delete_cookie.present?, "Expected deletion cookie in Set-Cookie header"

    # Verify the deletion cookie has the same domain as the original
    delete_domain = delete_cookie[/domain=([^;]+)/, 1]
    assert_equal set_domain, delete_domain, "Deletion cookie domain should match set cookie domain"

    # Verify it's actually a deletion (empty value or past expiry)
    assert(
      delete_cookie.include?("jiki_user_id=;") ||
      delete_cookie.include?("max-age=0") ||
      delete_cookie.match?(/expires=.*1970/i), # Unix epoch = deletion
      "Expected cookie to be deleted, got: #{delete_cookie}"
    )
  end

  test "cookie is set when user confirms email" do
    unconfirmed_user = create(:user, :unconfirmed, email: "unconfirmed@example.com")
    token = unconfirmed_user.confirmation_token

    get user_confirmation_path(confirmation_token: token), as: :json

    assert_response :ok
    assert_cookie_set
  end

  test "cookie is not set when login fails with wrong password" do
    post user_session_path, params: {
      user: { email: "test@example.com", password: "wrongpassword" }
    }, as: :json

    assert_response :unauthorized
    assert_cookie_cleared
  end

  test "cookie is not set when login fails with non-existent email" do
    post user_session_path, params: {
      user: { email: "nonexistent@example.com", password: "password123" }
    }, as: :json

    assert_response :unauthorized
    assert_cookie_cleared
  end

  test "cookie is not set for unconfirmed user login attempt" do
    create(:user, :unconfirmed, email: "unconfirmed@example.com", password: "password123")

    post user_session_path, params: {
      user: { email: "unconfirmed@example.com", password: "password123" }
    }, as: :json

    assert_response :unauthorized
    assert_cookie_cleared
  end

  test "cookie is not set for unauthenticated requests" do
    get internal_me_path, as: :json

    assert_response :unauthorized
    assert_cookie_cleared
  end

  test "cookie has httponly attribute" do
    post user_session_path, params: {
      user: { email: "test@example.com", password: "password123" }
    }, as: :json

    assert_response :ok
    cookie = jiki_user_id_cookie
    assert_includes cookie, "httponly", "Expected cookie to have httponly attribute"
  end

  test "cookie persists across authenticated requests" do
    # Login
    post user_session_path, params: {
      user: { email: "test@example.com", password: "password123" }
    }, as: :json
    assert_response :ok
    assert_cookie_set

    # Make another authenticated request
    get internal_me_path, as: :json
    assert_response :ok
    assert_cookie_set
  end

  private
  def jiki_user_id_cookie
    cookie_headers = response.headers["Set-Cookie"]
    return nil if cookie_headers.blank?

    # Set-Cookie can be an array or a string
    cookie_headers = [cookie_headers] unless cookie_headers.is_a?(Array)
    cookie_headers.find { |c| c.start_with?("jiki_user_id=") }
  end

  def assert_cookie_set
    cookie = jiki_user_id_cookie
    assert cookie.present?, "Expected jiki_user_id cookie to be set"
    refute cookie.start_with?("jiki_user_id=;"), "Cookie should have a value, not be empty"
  end

  def assert_cookie_cleared
    cookie = jiki_user_id_cookie
    # Cookie is either not set, or set to empty/deleted
    return if cookie.blank?

    # If the cookie is present, it should be a deletion (empty value or max-age=0)
    assert(
      cookie.start_with?("jiki_user_id=;") || cookie.include?("max-age=0"),
      "Expected jiki_user_id cookie to be cleared, got: #{cookie}"
    )
  end
end
