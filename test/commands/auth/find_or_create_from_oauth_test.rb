require "test_helper"

class Auth::FindOrCreateFromOauthTest < ActiveSupport::TestCase
  test "raises ArgumentError for unknown provider" do
    assert_raises(ArgumentError) do
      Auth::FindOrCreateFromOauth.(:facebook, { 'id' => 'x', 'email' => 'x@example.com' })
    end
  end

  test "stores the id against the column for the given provider (google)" do
    user = find_or_create_google({ 'id' => 'google-123', 'email' => 'user@gmail.com', 'name' => 'Google User' })

    assert_equal 'google-123', user.google_id
    assert_nil user.exercism_id
  end

  test "stores the id against the column for the given provider (exercism)" do
    user = find_or_create_exercism({ 'id' => '1530', 'email' => 'ihid@exercism.org', 'name' => 'Jeremy Walker' })

    assert_equal '1530', user.exercism_id
    assert_nil user.google_id
  end

  test "raises InvalidOauthPayloadError when id is blank" do
    assert_raises(InvalidOauthPayloadError) do
      find_or_create_exercism({ 'id' => nil, 'email' => 'someone@exercism.org', 'name' => 'Someone' })
    end
  end

  test "raises InvalidOauthPayloadError when email is blank" do
    assert_raises(InvalidOauthPayloadError) do
      find_or_create_exercism({ 'id' => '1530', 'email' => '', 'name' => 'Someone' })
    end
  end

  test "creates new user" do
    assert_difference 'User.count', 1 do
      user = find_or_create_exercism({
        'id' => '1530',
        'email' => 'newuser@exercism.org',
        'name' => 'New User',
        'handle' => 'iHiD'
      })

      assert_equal 'newuser@exercism.org', user.email
      assert_equal 'New User', user.name
      assert_equal '1530', user.exercism_id
      assert user.uses_oauth?
      assert user.confirmed?
      assert_equal 'ihid', user.handle
    end
  end

  test "generates handle from email when no handle in payload" do
    user = find_or_create_google({ 'id' => 'google-123', 'email' => 'someone@gmail.com', 'name' => 'Someone' })

    assert_equal 'someone', user.handle
  end

  test "falls back to generated handle when payload handle is taken" do
    create(:user, handle: 'ihid')

    user = find_or_create_exercism({
      'id' => '1530',
      'email' => 'jeremy@exercism.org',
      'name' => 'Jeremy Walker',
      'handle' => 'iHiD'
    })

    # Falls back to generating a handle from the email
    assert_equal 'jeremy', user.handle
  end

  test "handles email with special characters in handle generation" do
    user = find_or_create_google({ 'id' => 'google-123', 'email' => 'test.user+tag@gmail.com', 'name' => 'Test User' })

    # parameterize should convert special chars
    assert_equal 'test-user-tag', user.handle
  end

  test "appends suffix when generated handle is also taken" do
    create(:user, handle: 'testuser')

    user = find_or_create_google({ 'id' => 'google-123', 'email' => 'testuser@gmail.com', 'name' => 'Test User' })

    assert user.handle.start_with?('testuser')
    refute_equal 'testuser', user.handle
    assert_match(/\Atestuser-[a-f0-9]{6}\z/, user.handle)
  end

  test "finds existing user by provider id" do
    existing_user = create(:user, email: 'existing@exercism.org', exercism_id: '456')

    assert_no_difference 'User.count' do
      user = find_or_create_exercism({ 'id' => '456', 'email' => 'existing@exercism.org', 'name' => 'Existing User' })

      assert_equal existing_user.id, user.id
    end
  end

  test "links existing user by email when provider id not found" do
    existing_user = create(:user,
      email: 'existing@exercism.org',
      exercism_id: nil,
      confirmed_at: nil)

    assert_no_difference 'User.count' do
      user = find_or_create_exercism({ 'id' => '789', 'email' => 'existing@exercism.org', 'name' => 'Existing User' })

      assert_equal existing_user.id, user.id
      assert_equal '789', user.exercism_id
      assert user.uses_oauth?
      assert user.confirmed?
    end
  end

  test "linking by email is additive across providers" do
    existing_user = create(:user, email: 'both@example.com', google_id: 'google-123')

    user = find_or_create_exercism({ 'id' => '1530', 'email' => 'both@example.com', 'name' => 'Both User' })

    assert_equal existing_user.id, user.id
    assert_equal 'google-123', user.google_id
    assert_equal '1530', user.exercism_id
  end

  test "defers avatar copy for new user with avatar_url" do
    User::Avatar::CopyFromUrl.expects(:defer).with do |user, url|
      user.email == 'avatar@exercism.org' && url == 'https://exercism.org/avatars/1530/0'
    end

    find_or_create_exercism({
      'id' => '1530',
      'email' => 'avatar@exercism.org',
      'name' => 'Avatar User',
      'avatar_url' => 'https://exercism.org/avatars/1530/0'
    })
  end

  test "does not defer avatar copy when avatar_url is blank" do
    User::Avatar::CopyFromUrl.expects(:defer).never

    find_or_create_exercism({ 'id' => '1530', 'email' => 'noavatar@exercism.org', 'name' => 'No Avatar' })
  end

  test "does not defer avatar copy when linking existing user by email" do
    create(:user, email: 'existing@exercism.org', exercism_id: nil)

    User::Avatar::CopyFromUrl.expects(:defer).never

    find_or_create_exercism({
      'id' => '789',
      'email' => 'existing@exercism.org',
      'name' => 'Existing User',
      'avatar_url' => 'https://exercism.org/avatars/789/0'
    })
  end

  test "links existing user by email when payload email has different casing" do
    existing_user = create(:user, email: 'existing@exercism.org', exercism_id: nil)

    assert_no_difference 'User.count' do
      user = find_or_create_exercism({ 'id' => '789', 'email' => 'Existing@Exercism.ORG', 'name' => 'Existing User' })

      assert_equal existing_user.id, user.id
      assert_equal '789', user.exercism_id
    end
  end

  test "recovers when a concurrent request creates the user between lookup and insert" do
    # Simulate the race: the email lookup finds nothing, but by the time we
    # INSERT, a concurrent request has created the user.
    concurrent_user = create(:user, email: 'raced@gmail.com', google_id: nil)
    User.stubs(:find_by).with(google_id: 'google-123').returns(nil)
    User.stubs(:find_by).with(email: 'raced@gmail.com').returns(nil, concurrent_user)
    User.expects(:create!).raises(ActiveRecord::RecordNotUnique)

    assert_no_difference 'User.count' do
      user = find_or_create_google({ 'id' => 'google-123', 'email' => 'raced@gmail.com', 'name' => 'Raced User' })

      assert_equal concurrent_user.id, user.id
      assert_equal 'google-123', user.google_id
      assert user.confirmed?
    end
  end

  test "reraises RecordNotUnique when no user exists with the email" do
    User.expects(:create!).raises(ActiveRecord::RecordNotUnique)

    assert_raises(ActiveRecord::RecordNotUnique) do
      find_or_create_google({ 'id' => 'google-123', 'email' => 'ghost@gmail.com', 'name' => 'Ghost User' })
    end
  end

  test "generates random password for new users" do
    user = find_or_create_exercism({ 'id' => '1530', 'email' => 'password@exercism.org', 'name' => 'Password Test' })

    # User should have an encrypted password (random generated)
    assert user.encrypted_password.present?
    # Should not be able to login with empty password
    refute user.valid_password?("")
  end

  private
  def find_or_create_exercism(payload)
    Auth::FindOrCreateFromOauth.(:exercism, payload)
  end

  def find_or_create_google(payload)
    Auth::FindOrCreateFromOauth.(:google, payload)
  end
end
