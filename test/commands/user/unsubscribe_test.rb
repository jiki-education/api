require "test_helper"

class User::UnsubscribeTest < ActiveSupport::TestCase
  test "unsubscribes user with valid token" do
    user = create(:user)
    token = user.data.unsubscribe_token

    freeze_time do
      result = User::Unsubscribe.(token)

      assert_equal user, result
      user.reload
      assert_equal Time.current, user.data.email_complaint_at
      assert_equal 'unsubscribe_rfc_8058', user.data.email_complaint_type
    end
  end

  test "returns the user object" do
    user = create(:user)
    token = user.data.unsubscribe_token

    result = User::Unsubscribe.(token)

    assert_equal user, result
    assert_kind_of User, result
  end

  test "raises InvalidUnsubscribeTokenError for non-existent token" do
    error = assert_raises InvalidUnsubscribeTokenError do
      User::Unsubscribe.('invalid-token-that-does-not-exist')
    end

    assert_kind_of InvalidUnsubscribeTokenError, error
  end

  test "raises InvalidUnsubscribeTokenError for nil token" do
    assert_raises InvalidUnsubscribeTokenError do
      User::Unsubscribe.(nil)
    end
  end

  test "raises InvalidUnsubscribeTokenError for empty token" do
    assert_raises InvalidUnsubscribeTokenError do
      User::Unsubscribe.('')
    end
  end

  test "sets complaint type to unsubscribe_rfc_8058" do
    user = create(:user)
    token = user.data.unsubscribe_token

    User::Unsubscribe.(token)

    assert_equal 'unsubscribe_rfc_8058', user.reload.data.email_complaint_type
  end

  test "updates existing complaint data if already complained" do
    user = create(:user)
    user.data.update!(
      email_complaint_at: 1.week.ago,
      email_complaint_type: 'abuse'
    )
    token = user.data.unsubscribe_token

    freeze_time do
      User::Unsubscribe.(token)

      user.reload
      assert_equal Time.current, user.data.email_complaint_at
      assert_equal 'unsubscribe_rfc_8058', user.data.email_complaint_type
    end
  end
end
