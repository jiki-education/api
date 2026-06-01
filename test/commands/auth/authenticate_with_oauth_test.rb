require "test_helper"

class Auth::AuthenticateWithOauthTest < ActiveSupport::TestCase
  test "raises ArgumentError for unknown provider" do
    assert_raises(ArgumentError) do
      Auth::AuthenticateWithOauth.(:facebook, 'some-code')
    end
  end

  test "verifies Google tokens with the Google command" do
    payload = { 'id' => 'google-123', 'email' => 'user@gmail.com', 'name' => 'Test User' }

    Auth::VerifyGoogleToken.expects(:call).with('google-token').returns(payload)

    user = Auth::AuthenticateWithOauth.(:google, 'google-token')

    assert_equal 'google-123', user.google_id
  end

  test "verifies Exercism tokens with the Exercism command, passing all token args" do
    payload = { 'id' => '1530', 'email' => 'ihid@exercism.org', 'name' => 'Jeremy Walker' }

    Auth::VerifyExercismToken.expects(:call).with('exercism-code', 'code-verifier').returns(payload)

    Auth::AuthenticateWithOauth.(:exercism, 'exercism-code', 'code-verifier')

    assert User.exists?(exercism_id: '1530')
  end

  test "raises InvalidOauthPayloadError when id is blank" do
    stub_exercism_payload({ 'id' => nil, 'email' => 'someone@exercism.org', 'name' => 'Someone' })

    assert_raises(InvalidOauthPayloadError) do
      authenticate_with_exercism!
    end
  end

  test "raises InvalidOauthPayloadError when email is blank" do
    stub_exercism_payload({ 'id' => '1530', 'email' => '', 'name' => 'Someone' })

    assert_raises(InvalidOauthPayloadError) do
      authenticate_with_exercism!
    end
  end

  test "creates new user" do
    stub_exercism_payload({
      'id' => '1530',
      'email' => 'newuser@exercism.org',
      'name' => 'New User',
      'handle' => 'iHiD'
    })

    assert_difference 'User.count', 1 do
      user = authenticate_with_exercism!

      assert_equal 'newuser@exercism.org', user.email
      assert_equal 'New User', user.name
      assert_equal '1530', user.exercism_id
      assert user.uses_oauth?
      assert user.confirmed?
      assert_equal 'ihid', user.handle
    end
  end

  test "stores the id against the column for the given provider" do
    stub_google_payload({ 'id' => 'google-123', 'email' => 'user@gmail.com', 'name' => 'Google User' })

    user = authenticate_with_google!

    assert_equal 'google-123', user.google_id
    assert_nil user.exercism_id
  end

  test "generates handle from email when no handle in payload" do
    stub_google_payload({ 'id' => 'google-123', 'email' => 'someone@gmail.com', 'name' => 'Someone' })

    user = authenticate_with_google!

    assert_equal 'someone', user.handle
  end

  test "falls back to generated handle when payload handle is taken" do
    create(:user, handle: 'ihid')

    stub_exercism_payload({
      'id' => '1530',
      'email' => 'jeremy@exercism.org',
      'name' => 'Jeremy Walker',
      'handle' => 'iHiD'
    })

    user = authenticate_with_exercism!

    # Falls back to generating a handle from the email
    assert_equal 'jeremy', user.handle
  end

  test "handles email with special characters in handle generation" do
    stub_google_payload({ 'id' => 'google-123', 'email' => 'test.user+tag@gmail.com', 'name' => 'Test User' })

    user = authenticate_with_google!

    # parameterize should convert special chars
    assert_equal 'test-user-tag', user.handle
  end

  test "appends suffix when generated handle is also taken" do
    create(:user, handle: 'testuser')

    stub_google_payload({ 'id' => 'google-123', 'email' => 'testuser@gmail.com', 'name' => 'Test User' })

    user = authenticate_with_google!

    assert user.handle.start_with?('testuser')
    refute_equal 'testuser', user.handle
    assert_match(/\Atestuser-[a-f0-9]{6}\z/, user.handle)
  end

  test "finds existing user by provider id" do
    existing_user = create(:user, email: 'existing@exercism.org', exercism_id: '456')

    stub_exercism_payload({ 'id' => '456', 'email' => 'existing@exercism.org', 'name' => 'Existing User' })

    assert_no_difference 'User.count' do
      user = authenticate_with_exercism!

      assert_equal existing_user.id, user.id
    end
  end

  test "links existing user by email when provider id not found" do
    existing_user = create(:user,
      email: 'existing@exercism.org',
      exercism_id: nil,
      confirmed_at: nil)

    stub_exercism_payload({ 'id' => '789', 'email' => 'existing@exercism.org', 'name' => 'Existing User' })

    assert_no_difference 'User.count' do
      user = authenticate_with_exercism!

      assert_equal existing_user.id, user.id
      assert_equal '789', user.exercism_id
      assert user.uses_oauth?
      assert user.confirmed?
    end
  end

  test "linking by email is additive across providers" do
    existing_user = create(:user, email: 'both@example.com', google_id: 'google-123')

    stub_exercism_payload({ 'id' => '1530', 'email' => 'both@example.com', 'name' => 'Both User' })

    user = authenticate_with_exercism!

    assert_equal existing_user.id, user.id
    assert_equal 'google-123', user.google_id
    assert_equal '1530', user.exercism_id
  end

  test "defers avatar copy for new user with avatar_url" do
    stub_exercism_payload({
      'id' => '1530',
      'email' => 'avatar@exercism.org',
      'name' => 'Avatar User',
      'avatar_url' => 'https://exercism.org/avatars/1530/0'
    })

    User::Avatar::CopyFromUrl.expects(:defer).with do |user, url|
      user.email == 'avatar@exercism.org' && url == 'https://exercism.org/avatars/1530/0'
    end

    authenticate_with_exercism!
  end

  test "does not defer avatar copy when avatar_url is blank" do
    stub_exercism_payload({ 'id' => '1530', 'email' => 'noavatar@exercism.org', 'name' => 'No Avatar' })

    User::Avatar::CopyFromUrl.expects(:defer).never

    authenticate_with_exercism!
  end

  test "does not defer avatar copy when linking existing user by email" do
    create(:user, email: 'existing@exercism.org', exercism_id: nil)

    stub_exercism_payload({
      'id' => '789',
      'email' => 'existing@exercism.org',
      'name' => 'Existing User',
      'avatar_url' => 'https://exercism.org/avatars/789/0'
    })

    User::Avatar::CopyFromUrl.expects(:defer).never

    authenticate_with_exercism!
  end

  test "generates random password for new users" do
    stub_exercism_payload({ 'id' => '1530', 'email' => 'password@exercism.org', 'name' => 'Password Test' })

    user = authenticate_with_exercism!

    # User should have an encrypted password (random generated)
    assert user.encrypted_password.present?
    # Should not be able to login with empty password
    refute user.valid_password?("")
  end

  private
  def stub_exercism_payload(payload)
    Auth::VerifyExercismToken.stubs(:call).returns(payload)
  end

  def stub_google_payload(payload)
    Auth::VerifyGoogleToken.stubs(:call).returns(payload)
  end

  def authenticate_with_exercism!
    Auth::AuthenticateWithOauth.(:exercism, 'exercism-code', 'code-verifier')
  end

  def authenticate_with_google!
    Auth::AuthenticateWithOauth.(:google, 'google-token')
  end
end
