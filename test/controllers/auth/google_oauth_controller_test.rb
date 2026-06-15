require "test_helper"

class Auth::GoogleOauthControllerTest < ApplicationControllerTest
  test "POST google with valid code creates new user and signs them in" do
    google_payload = {
      'id' => 'google-user-id-123',
      'email' => 'newuser@gmail.com',
      'name' => 'New User',
      'exp' => 1.hour.from_now.to_i
    }

    Auth::VerifyGoogleToken.stubs(:call).returns(google_payload)

    user_capture = nil
    User::Bootstrap.expects(:call).with do |user, provider, **|
      user_capture = user
      user.email == 'newuser@gmail.com' && provider == "google"
    end

    assert_difference 'User.count', 1 do
      post auth_google_path, params: { code: 'valid-google-auth-code' }, as: :json
    end

    assert_response :ok

    # Check user was created correctly
    user = User.find_by(email: 'newuser@gmail.com')
    refute_nil user
    assert_equal user.id, user_capture&.id
    assert_equal 'google-user-id-123', user.google_id
    assert user.uses_oauth?
    assert user.confirmed?
    assert_equal 'newuser', user.handle

    # Check response
    assert_json_response({
      status: "success",
      user: SerializeUser.(user)
    })
  end

  test "POST google forwards CF-IPCountry header to User::Bootstrap" do
    google_payload = {
      'id' => 'google-country-id',
      'email' => 'country@gmail.com',
      'name' => 'Country User',
      'exp' => 1.hour.from_now.to_i
    }

    Auth::VerifyGoogleToken.stubs(:call).returns(google_payload)

    User::Bootstrap.expects(:call).with(
      instance_of(User),
      "google",
      has_entries(country_code: "JP")
    )

    post auth_google_path,
      params: { code: 'valid-google-auth-code' },
      headers: { "CF-IPCountry" => "JP" },
      as: :json

    assert_response :ok
  end

  test "POST google with valid code for existing google user signs them in" do
    existing_user = create(:user,
      email: 'existing@gmail.com',
      google_id: 'google-user-id-456',
      confirmed_at: Time.current)

    google_payload = {
      'id' => 'google-user-id-456',
      'email' => 'existing@gmail.com',
      'name' => 'Existing User',
      'exp' => 1.hour.from_now.to_i
    }

    Auth::VerifyGoogleToken.stubs(:call).returns(google_payload)

    User::Bootstrap.expects(:call).never

    assert_no_difference 'User.count' do
      post auth_google_path, params: { code: 'valid-google-auth-code' }, as: :json
    end

    assert_response :ok
    assert_json_response({
      status: "success",
      user: SerializeUser.(existing_user)
    })
  end

  test "POST google links existing email user to Google account" do
    existing_user = create(:user, email: 'existing@gmail.com', google_id: nil)

    google_payload = {
      'id' => 'google-user-id-789',
      'email' => 'existing@gmail.com',
      'name' => 'Existing User',
      'exp' => 1.hour.from_now.to_i
    }

    Auth::VerifyGoogleToken.stubs(:call).returns(google_payload)

    User::Bootstrap.expects(:call).never

    assert_no_difference 'User.count' do
      post auth_google_path, params: { code: 'valid-google-auth-code' }, as: :json
    end

    assert_response :ok

    # Check user was linked to Google
    existing_user.reload
    assert_equal 'google-user-id-789', existing_user.google_id
    assert existing_user.uses_oauth?
    assert existing_user.confirmed?

    assert_json_response({
      status: "success",
      user: SerializeUser.(existing_user)
    })
  end

  test "POST google with malformed payload returns unauthorized" do
    # Payload missing the id - guarded by FindOrCreateFromOauth
    Auth::VerifyGoogleToken.stubs(:call).returns({
      'id' => nil,
      'email' => 'someone@gmail.com',
      'name' => 'Someone'
    })

    assert_no_difference 'User.count' do
      post auth_google_path, params: { code: 'valid-code' }, as: :json
    end

    assert_response :unauthorized

    json = response.parsed_body
    assert_equal 'invalid_token', json['error']['type']
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
      'id' => 'google-user-id-collision',
      'email' => 'testuser@gmail.com',
      'name' => 'Test User',
      'exp' => 1.hour.from_now.to_i
    }

    Auth::VerifyGoogleToken.stubs(:call).returns(google_payload)
    User::Bootstrap.stubs(:call)

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

  test "POST google fires user_logged_in for returning user" do
    existing_user = create(:user,
      email: 'existing@gmail.com',
      google_id: 'google-returning-id',
      confirmed_at: Time.current)

    Auth::VerifyGoogleToken.stubs(:call).returns({
      'id' => 'google-returning-id',
      'email' => 'existing@gmail.com',
      'name' => 'Existing User',
      'exp' => 1.hour.from_now.to_i
    })

    Analytics::TrackEvent.stubs(:defer)
    Analytics::TrackEvent.expects(:defer).with(
      existing_user,
      "user_logged_in",
      properties: { login_method: "google", via_2fa: false }
    )

    post auth_google_path, params: { code: 'valid-google-auth-code' }, as: :json

    assert_response :ok
  end

  test "POST google does not fire user_logged_in for newly created user" do
    Auth::VerifyGoogleToken.stubs(:call).returns({
      'id' => 'google-new-id',
      'email' => 'brandnew@gmail.com',
      'name' => 'Brand New',
      'exp' => 1.hour.from_now.to_i
    })
    User::Bootstrap.stubs(:call)

    Analytics::TrackEvent.stubs(:defer)
    Analytics::TrackEvent.expects(:defer).with(anything, "user_logged_in", anything).never

    post auth_google_path, params: { code: 'valid-google-auth-code' }, as: :json

    assert_response :ok
  end

  test "POST google for admin with 2FA enabled returns 2fa_required" do
    admin = create(:user, :admin,
      email: 'admin@gmail.com',
      google_id: 'google-admin-id',
      confirmed_at: Time.current)
    User::GenerateOtpSecret.(admin)
    User::EnableOtp.(admin)

    google_payload = {
      'id' => 'google-admin-id',
      'email' => 'admin@gmail.com',
      'name' => 'Admin User',
      'exp' => 1.hour.from_now.to_i
    }

    Auth::VerifyGoogleToken.stubs(:call).returns(google_payload)

    post auth_google_path, params: { code: 'valid-google-auth-code' }, as: :json

    assert_response :ok
    assert_json_response({ status: "2fa_required" })

    # Verify user is NOT signed in yet
    get internal_me_path, as: :json
    assert_response :unauthorized
  end

  test "POST google for admin without 2FA returns 2fa_setup_required" do
    create(:user, :admin,
      email: 'newadmin@gmail.com',
      google_id: 'google-newadmin-id',
      confirmed_at: Time.current)

    google_payload = {
      'id' => 'google-newadmin-id',
      'email' => 'newadmin@gmail.com',
      'name' => 'New Admin',
      'exp' => 1.hour.from_now.to_i
    }

    Auth::VerifyGoogleToken.stubs(:call).returns(google_payload)

    post auth_google_path, params: { code: 'valid-google-auth-code' }, as: :json

    assert_response :ok

    json = response.parsed_body
    assert_equal "2fa_setup_required", json["status"]
    assert json["provisioning_uri"].present?
    assert json["provisioning_uri"].start_with?("otpauth://totp/Jiki:")

    # Verify user is NOT signed in yet
    get internal_me_path, as: :json
    assert_response :unauthorized
  end
end
