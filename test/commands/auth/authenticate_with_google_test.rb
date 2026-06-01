require "test_helper"

class Auth::AuthenticateWithGoogleTest < ActiveSupport::TestCase
  test "proxies to AuthenticateWithOauth with the Google payload" do
    user = create(:user)
    payload = {
      'id' => 'google-123',
      'email' => 'user@gmail.com',
      'name' => 'Test User',
      'email_verified' => true,
      'avatar_url' => 'https://lh3.googleusercontent.com/photo.jpg'
    }

    Auth::VerifyGoogleToken.expects(:call).with('google-token').returns(payload)
    Auth::AuthenticateWithOauth.expects(:call).with(:google, payload).returns(user)

    assert_equal user, Auth::AuthenticateWithGoogle.('google-token')
  end
end
