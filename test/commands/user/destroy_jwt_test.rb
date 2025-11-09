require "test_helper"

class User::DestroyJWTSecurityTest < ActionDispatch::IntegrationTest
  test "JWT tokens are invalidated after user deletion" do
    # Create a user and sign in to get a JWT token
    user = create(:user, email: "jwt-test@example.com", password: "password123")
    user_id = user.id

    # Sign in to get JWT token
    post user_session_path, params: {
      user: {
        email: "jwt-test@example.com",
        password: "password123"
      }
    }, as: :json

    assert_response :success

    # Extract the JWT token from the Authorization header
    jwt_token = response.headers["Authorization"]
    refute_nil jwt_token, "JWT token should be present in Authorization header"

    # Verify the token works before deletion
    get internal_user_levels_path, headers: { "Authorization" => jwt_token }, as: :json
    assert_response :success, "Token should work before user deletion"

    # Delete the user
    User::Destroy.(User.find(user_id))

    # Verify user is deleted
    assert_nil User.find_by(id: user_id)

    # Attempt to use the JWT token after user deletion
    # This should fail because the user no longer exists
    get internal_user_levels_path, headers: { "Authorization" => jwt_token }, as: :json
    assert_response :unauthorized, "Token should be invalid after user deletion"
  end
end
