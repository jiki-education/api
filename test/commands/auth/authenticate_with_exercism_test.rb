require "test_helper"

class Auth::AuthenticateWithExercismTest < ActiveSupport::TestCase
  test "proxies to AuthenticateWithOauth with the Exercism payload" do
    user = create(:user)
    payload = {
      'id' => '1530',
      'email' => 'ihid@exercism.org',
      'name' => 'Jeremy Walker',
      'handle' => 'iHiD',
      'avatar_url' => 'https://exercism.org/avatars/1530/0'
    }

    Auth::VerifyExercismToken.expects(:call).with('exercism-code', 'code-verifier').returns(payload)
    Auth::AuthenticateWithOauth.expects(:call).with(:exercism, payload).returns(user)

    assert_equal user, Auth::AuthenticateWithExercism.('exercism-code', 'code-verifier')
  end
end
