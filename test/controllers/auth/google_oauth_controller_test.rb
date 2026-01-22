require "test_helper"

class Auth::GoogleOauthControllerTest < ApplicationControllerTest
  test "POST google with valid code creates new user and signs them in" do
    google_payload = {
      'sub' => 'google-user-id-123',
      'email' => 'newuser@gmail.com',
      'name' => 'New User',
      'exp' => 1.hour.from_now.to_i
    }

    Auth::VerifyGoogleToken.stubs(:call).returns(google_payload)

    assert_difference 'User.count', 1 do
      post auth_google_path, params: { code: 'valid-google-auth-code' }, as: :json
    end

    assert_response :ok

    # Check user was created correctly
    user = User.find_by(email: 'newuser@gmail.com')
    refute_nil user
    assert_equal 'google-user-id-123', user.google_id
    assert_equal 'google', user.provider
    assert user.confirmed?
    assert_equal 'newuser', user.handle

    # Check response
    json = response.parsed_body
    assert_equal 'newuser', json['user']['handle']
    assert_equal 'newuser@gmail.com', json['user']['email']
    assert_equal 'New User', json['user']['name']
    assert_equal 'google', json['user']['provider']
    assert json['user']['email_confirmed']
  end

  test "POST google with valid code for existing google user signs them in" do
    existing_user = create(:user,
      email: 'existing@gmail.com',
      google_id: 'google-user-id-456',
      provider: 'google',
      confirmed_at: Time.current)

    google_payload = {
      'sub' => 'google-user-id-456',
      'email' => 'existing@gmail.com',
      'name' => 'Existing User',
      'exp' => 1.hour.from_now.to_i
    }

    Auth::VerifyGoogleToken.stubs(:call).returns(google_payload)

    assert_no_difference 'User.count' do
      post auth_google_path, params: { code: 'valid-google-auth-code' }, as: :json
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
      post auth_google_path, params: { code: 'valid-google-auth-code' }, as: :json
    end

    assert_response :ok

    # Check user was linked to Google
    existing_user.reload
    assert_equal 'google-user-id-789', existing_user.google_id
    assert_equal 'google', existing_user.provider
    assert existing_user.confirmed?

    json = response.parsed_body
    assert_equal existing_user.handle, json['user']['handle']
    assert_equal 'google', json['user']['provider']
  end

  test "POST google with invalid code returns unauthorized" do
    Auth::VerifyGoogleToken.stubs(:call).raises(
      InvalidGoogleTokenError.new("Invalid Google token")
    )

    assert_no_difference 'User.count' do
      post auth_google_path, params: { code: 'invalid-code' }, as: :json
    end

    assert_response :unauthorized

    json = response.parsed_body
    assert_equal 'invalid_token', json['error']['type']
    assert_match(/Invalid Google token/, json['error']['message'])
  end

  test "POST google with expired code returns unauthorized" do
    Auth::VerifyGoogleToken.stubs(:call).raises(
      InvalidGoogleTokenError.new("Token expired")
    )

    assert_no_difference 'User.count' do
      post auth_google_path, params: { code: 'expired-code' }, as: :json
    end

    assert_response :unauthorized

    json = response.parsed_body
    assert_equal 'invalid_token', json['error']['type']
    assert_match(/Token expired/, json['error']['message'])
  end

  test "POST google generates unique handle when email prefix is taken" do
    create(:user, handle: 'testuser')

    google_payload = {
      'sub' => 'google-user-id-collision',
      'email' => 'testuser@gmail.com',
      'name' => 'Test User',
      'exp' => 1.hour.from_now.to_i
    }

    Auth::VerifyGoogleToken.stubs(:call).returns(google_payload)

    post auth_google_path, params: { code: 'valid-google-auth-code' }, as: :json

    assert_response :ok

    user = User.find_by(email: 'testuser@gmail.com')
    # Handle should be testuser + random hex suffix
    assert user.handle.start_with?('testuser')
    refute_equal 'testuser', user.handle
    assert_match(/\Atestuser-[a-f0-9]{6}\z/, user.handle)
  end

  test "POST google without code parameter returns error" do
    # Stub the Google token verification to raise an error for nil code
    Auth::VerifyGoogleToken.stubs(:call).raises(
      InvalidGoogleTokenError.new("Invalid Google token")
    )

    assert_no_difference 'User.count' do
      post auth_google_path, params: {}, as: :json
    end

    # This will cause an error in VerifyGoogleToken
    assert_response :unauthorized
  end
end
