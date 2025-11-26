require "test_helper"

class Auth::AuthenticateWithGoogleTest < ActiveSupport::TestCase
  test "creates new user from Google token" do
    google_payload = {
      'sub' => 'google-123',
      'email' => 'newuser@gmail.com',
      'name' => 'New User'
    }

    Auth::VerifyGoogleToken.stubs(:call).returns(google_payload)

    assert_difference 'User.count', 1 do
      user = Auth::AuthenticateWithGoogle.('google-token')
      assert_equal 'newuser@gmail.com', user.email
      assert_equal 'New User', user.name
      assert_equal 'google-123', user.google_id
      assert_equal 'google', user.provider
      assert user.email_verified
      assert_equal 'newuser', user.handle
    end
  end

  test "finds existing user by google_id" do
    existing_user = create(:user,
      email: 'existing@gmail.com',
      google_id: 'google-456',
      provider: 'google')

    google_payload = {
      'sub' => 'google-456',
      'email' => 'existing@gmail.com',
      'name' => 'Existing User'
    }

    Auth::VerifyGoogleToken.stubs(:call).returns(google_payload)

    assert_no_difference 'User.count' do
      user = Auth::AuthenticateWithGoogle.('google-token')

      assert_equal existing_user.id, user.id
    end
  end

  test "links existing user by email when google_id not found" do
    existing_user = create(:user,
      email: 'existing@gmail.com',
      google_id: nil,
      provider: nil,
      email_verified: false)

    google_payload = {
      'sub' => 'google-789',
      'email' => 'existing@gmail.com',
      'name' => 'Existing User'
    }

    Auth::VerifyGoogleToken.stubs(:call).returns(google_payload)

    assert_no_difference 'User.count' do
      user = Auth::AuthenticateWithGoogle.('google-token')
      assert_equal existing_user.id, user.id
      assert_equal 'google-789', user.google_id
      assert_equal 'google', user.provider
      assert user.email_verified
    end
  end

  test "generates unique handle when base handle is taken" do
    create(:user, handle: 'testuser')

    google_payload = {
      'sub' => 'google-collision',
      'email' => 'testuser@gmail.com',
      'name' => 'Test User'
    }

    Auth::VerifyGoogleToken.stubs(:call).returns(google_payload)

    user = Auth::AuthenticateWithGoogle.('google-token')

    # Handle should be testuser + random hex suffix
    assert user.handle.start_with?('testuser')
    refute_equal 'testuser', user.handle
    assert_match(/\Atestuser-[a-f0-9]{6}\z/, user.handle)
  end

  test "handles email with special characters in handle generation" do
    google_payload = {
      'sub' => 'google-special',
      'email' => 'test.user+tag@gmail.com',
      'name' => 'Test User'
    }

    Auth::VerifyGoogleToken.stubs(:call).returns(google_payload)

    user = Auth::AuthenticateWithGoogle.('google-token')

    # parameterize should convert special chars
    assert_equal 'test-user-tag', user.handle
  end

  test "generates random password for OAuth users" do
    google_payload = {
      'sub' => 'google-password',
      'email' => 'password@gmail.com',
      'name' => 'Password Test'
    }

    Auth::VerifyGoogleToken.stubs(:call).returns(google_payload)

    user = Auth::AuthenticateWithGoogle.('google-token')

    # User should have an encrypted password (random generated)
    assert user.encrypted_password.present?
    # Should not be able to login with empty password
    refute user.valid_password?("")
  end
end
