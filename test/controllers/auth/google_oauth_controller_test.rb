require "test_helper"

class Auth::GoogleOauthControllerTest < ApplicationControllerTest
  test "POST google with valid token creates new user and returns JWT" do
    google_payload = {
      'sub' => 'google-user-id-123',
      'email' => 'newuser@gmail.com',
      'name' => 'New User',
      'exp' => 1.hour.from_now.to_i
    }

    Auth::VerifyGoogleToken.stubs(:call).returns(google_payload)

    assert_difference 'User.count', 1 do
      post auth_google_path, params: { token: 'valid-google-token' }, as: :json
    end

    assert_response :ok

    # Check user was created correctly
    user = User.find_by(email: 'newuser@gmail.com')
    refute_nil user
    assert_equal 'google-user-id-123', user.google_id
    assert_equal 'google', user.provider
    assert user.email_verified
    assert_equal 'newuser', user.handle

    # Check response
    json = response.parsed_body
    assert_equal 'newuser', json['user']['handle']
    assert_equal 'newuser@gmail.com', json['user']['email']
    assert_equal 'New User', json['user']['name']
    assert_equal 'google', json['user']['provider']
    assert json['user']['email_verified']
    assert json['refresh_token'].present?

    # Check JWT token in header
    token = response.headers['Authorization']
    assert token.present?
    assert token.start_with?('Bearer ')
  end

  test "POST google with valid token for existing google user returns JWT" do
    existing_user = create(:user,
      email: 'existing@gmail.com',
      google_id: 'google-user-id-456',
      provider: 'google',
      email_verified: true)

    google_payload = {
      'sub' => 'google-user-id-456',
      'email' => 'existing@gmail.com',
      'name' => 'Existing User',
      'exp' => 1.hour.from_now.to_i
    }

    Auth::VerifyGoogleToken.stubs(:call).returns(google_payload)

    assert_no_difference 'User.count' do
      post auth_google_path, params: { token: 'valid-google-token' }, as: :json
    end

    assert_response :ok

    json = response.parsed_body
    assert_equal existing_user.handle, json['user']['handle']
    assert_equal 'existing@gmail.com', json['user']['email']
  end

  test "POST google links existing email user to Google account" do
    existing_user = create(:user, email: 'existing@gmail.com', provider: nil, google_id: nil)

    google_payload = {
      'sub' => 'google-user-id-789',
      'email' => 'existing@gmail.com',
      'name' => 'Existing User',
      'exp' => 1.hour.from_now.to_i
    }

    Auth::VerifyGoogleToken.stubs(:call).returns(google_payload)

    assert_no_difference 'User.count' do
      post auth_google_path, params: { token: 'valid-google-token' }, as: :json
    end

    assert_response :ok

    # Check user was linked to Google
    existing_user.reload
    assert_equal 'google-user-id-789', existing_user.google_id
    assert_equal 'google', existing_user.provider
    assert existing_user.email_verified

    json = response.parsed_body
    assert_equal existing_user.handle, json['user']['handle']
    assert_equal 'google', json['user']['provider']
  end

  test "POST google with invalid token returns unauthorized" do
    Auth::VerifyGoogleToken.stubs(:call).raises(
      InvalidGoogleTokenError.new("Invalid Google token")
    )

    post auth_google_path, params: { token: 'invalid-token' }, as: :json

    assert_response :unauthorized

    json = response.parsed_body
    assert_equal 'invalid_token', json['error']['type']
    assert_match(/Invalid Google token/, json['error']['message'])

    # No JWT token should be present
    assert_nil response.headers['Authorization']
  end

  test "POST google with expired token returns unauthorized" do
    Auth::VerifyGoogleToken.stubs(:call).raises(
      InvalidGoogleTokenError.new("Token expired")
    )

    post auth_google_path, params: { token: 'expired-token' }, as: :json

    assert_response :unauthorized

    json = response.parsed_body
    assert_equal 'invalid_token', json['error']['type']
    assert_match(/Token expired/, json['error']['message'])
  end

  test "POST google generates unique handle when email prefix is taken" do
    create(:user, handle: 'testuser')
    create(:user, handle: 'testuser1')

    google_payload = {
      'sub' => 'google-user-id-collision',
      'email' => 'testuser@gmail.com',
      'name' => 'Test User',
      'exp' => 1.hour.from_now.to_i
    }

    Auth::VerifyGoogleToken.stubs(:call).returns(google_payload)

    post auth_google_path, params: { token: 'valid-google-token' }, as: :json

    assert_response :ok

    user = User.find_by(email: 'testuser@gmail.com')
    assert_equal 'testuser2', user.handle
  end

  test "POST google without token parameter returns error" do
    # Stub the Google token verification to raise an error for nil token
    Auth::VerifyGoogleToken.stubs(:call).raises(
      InvalidGoogleTokenError.new("Invalid Google token")
    )

    post auth_google_path, params: {}, as: :json

    # This will cause an error in VerifyGoogleToken
    assert_response :unauthorized
  end
end
