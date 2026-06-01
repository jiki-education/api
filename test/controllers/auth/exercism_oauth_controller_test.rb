require "test_helper"

class Auth::ExercismOauthControllerTest < ApplicationControllerTest
  test "POST exercism with valid code creates new user and signs them in" do
    exercism_payload = {
      'id' => '1530',
      'email' => 'newuser@exercism.org',
      'name' => 'New User',
      'handle' => 'newuser',
      'avatar_url' => nil
    }

    Auth::VerifyExercismToken.stubs(:call).returns(exercism_payload)

    user_capture = nil
    User::Bootstrap.expects(:call).with do |user, provider, **|
      user_capture = user
      user.email == 'newuser@exercism.org' && provider == "exercism"
    end

    assert_difference 'User.count', 1 do
      post auth_exercism_path, params: { code: 'valid-exercism-auth-code', code_verifier: 'code-verifier' }, as: :json
    end

    assert_response :ok

    # Check user was created correctly
    user = User.find_by(email: 'newuser@exercism.org')
    refute_nil user
    assert_equal user.id, user_capture&.id
    assert_equal '1530', user.exercism_id
    assert_equal 'exercism', user.provider
    assert user.confirmed?
    assert_equal 'newuser', user.handle

    # Check response
    assert_json_response({
      status: "success",
      user: SerializeUser.(user)
    })
  end

  test "POST exercism with valid code for existing exercism user signs them in" do
    existing_user = create(:user,
      email: 'existing@exercism.org',
      exercism_id: '456',
      provider: 'exercism',
      confirmed_at: Time.current)

    exercism_payload = {
      'id' => '456',
      'email' => 'existing@exercism.org',
      'name' => 'Existing User',
      'handle' => 'existing',
      'avatar_url' => nil
    }

    Auth::VerifyExercismToken.stubs(:call).returns(exercism_payload)

    User::Bootstrap.expects(:call).never

    assert_no_difference 'User.count' do
      post auth_exercism_path, params: { code: 'valid-exercism-auth-code', code_verifier: 'code-verifier' }, as: :json
    end

    assert_response :ok
    assert_json_response({
      status: "success",
      user: SerializeUser.(existing_user)
    })
  end

  test "POST exercism links existing email user to Exercism account" do
    existing_user = create(:user, email: 'existing@exercism.org', provider: nil, exercism_id: nil)

    exercism_payload = {
      'id' => '789',
      'email' => 'existing@exercism.org',
      'name' => 'Existing User',
      'handle' => 'existing',
      'avatar_url' => nil
    }

    Auth::VerifyExercismToken.stubs(:call).returns(exercism_payload)

    User::Bootstrap.expects(:call).never

    assert_no_difference 'User.count' do
      post auth_exercism_path, params: { code: 'valid-exercism-auth-code', code_verifier: 'code-verifier' }, as: :json
    end

    assert_response :ok

    # Check user was linked to Exercism
    existing_user.reload
    assert_equal '789', existing_user.exercism_id
    assert_equal 'exercism', existing_user.provider
    assert existing_user.confirmed?

    assert_json_response({
      status: "success",
      user: SerializeUser.(existing_user)
    })
  end

  test "POST exercism with invalid code returns unauthorized" do
    Auth::VerifyExercismToken.stubs(:call).raises(
      InvalidExercismTokenError.new("Invalid Exercism token")
    )

    assert_no_difference 'User.count' do
      post auth_exercism_path, params: { code: 'invalid-code', code_verifier: 'code-verifier' }, as: :json
    end

    assert_response :unauthorized

    json = response.parsed_body
    assert_equal 'invalid_token', json['error']['type']
    assert_match(/Invalid Exercism token/, json['error']['message'])
  end

  test "POST exercism with expired code returns unauthorized" do
    Auth::VerifyExercismToken.stubs(:call).raises(
      InvalidExercismTokenError.new("Token expired")
    )

    assert_no_difference 'User.count' do
      post auth_exercism_path, params: { code: 'expired-code', code_verifier: 'code-verifier' }, as: :json
    end

    assert_response :unauthorized

    json = response.parsed_body
    assert_equal 'invalid_token', json['error']['type']
    assert_match(/Token expired/, json['error']['message'])
  end

  test "POST exercism falls back to generated handle when Exercism handle is taken" do
    create(:user, handle: 'testuser')

    exercism_payload = {
      'id' => '999',
      'email' => 'someoneelse@exercism.org',
      'name' => 'Test User',
      'handle' => 'testuser',
      'avatar_url' => nil
    }

    Auth::VerifyExercismToken.stubs(:call).returns(exercism_payload)
    User::Bootstrap.stubs(:call)

    post auth_exercism_path, params: { code: 'valid-exercism-auth-code', code_verifier: 'code-verifier' }, as: :json

    assert_response :ok

    user = User.find_by(email: 'someoneelse@exercism.org')
    # Handle should fall back to one generated from the email
    assert_equal 'someoneelse', user.handle
  end

  test "POST exercism without code parameter returns error" do
    # Stub the Exercism token verification to raise an error for nil code
    Auth::VerifyExercismToken.stubs(:call).raises(
      InvalidExercismTokenError.new("Invalid Exercism token")
    )

    assert_no_difference 'User.count' do
      post auth_exercism_path, params: {}, as: :json
    end

    # This will cause an error in VerifyExercismToken
    assert_response :unauthorized
  end

  test "POST exercism for admin with 2FA enabled returns 2fa_required" do
    admin = create(:user, :admin,
      email: 'admin@exercism.org',
      exercism_id: 'admin-id',
      provider: 'exercism',
      confirmed_at: Time.current)
    User::GenerateOtpSecret.(admin)
    User::EnableOtp.(admin)

    exercism_payload = {
      'id' => 'admin-id',
      'email' => 'admin@exercism.org',
      'name' => 'Admin User',
      'handle' => 'admin',
      'avatar_url' => nil
    }

    Auth::VerifyExercismToken.stubs(:call).returns(exercism_payload)

    post auth_exercism_path, params: { code: 'valid-exercism-auth-code', code_verifier: 'code-verifier' }, as: :json

    assert_response :ok
    assert_json_response({ status: "2fa_required" })

    # Verify user is NOT signed in yet
    get internal_me_path, as: :json
    assert_response :unauthorized
  end

  test "POST exercism for admin without 2FA returns 2fa_setup_required" do
    create(:user, :admin,
      email: 'newadmin@exercism.org',
      exercism_id: 'newadmin-id',
      provider: 'exercism',
      confirmed_at: Time.current)

    exercism_payload = {
      'id' => 'newadmin-id',
      'email' => 'newadmin@exercism.org',
      'name' => 'New Admin',
      'handle' => 'newadmin',
      'avatar_url' => nil
    }

    Auth::VerifyExercismToken.stubs(:call).returns(exercism_payload)

    post auth_exercism_path, params: { code: 'valid-exercism-auth-code', code_verifier: 'code-verifier' }, as: :json

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
