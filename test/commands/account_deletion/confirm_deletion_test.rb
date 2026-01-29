require "test_helper"

class AccountDeletion::ConfirmDeletionTest < ActiveSupport::TestCase
  test "deletes user with valid token" do
    user = create(:user)
    token = AccountDeletion::CreateDeletionToken.(user)

    assert_difference 'User.count', -1 do
      AccountDeletion::ConfirmDeletion.(token)
    end

    assert_nil User.find_by(id: user.id)
  end

  test "raises InvalidTokenError for invalid token" do
    assert_raises(AccountDeletion::ValidateDeletionToken::InvalidTokenError) do
      AccountDeletion::ConfirmDeletion.("invalid-token")
    end
  end

  test "raises TokenExpiredError for expired token" do
    user = create(:user)

    token = travel_to(2.hours.ago) do
      AccountDeletion::CreateDeletionToken.(user)
    end

    assert_raises(AccountDeletion::ValidateDeletionToken::TokenExpiredError) do
      AccountDeletion::ConfirmDeletion.(token)
    end
  end

  test "raises InvalidTokenError when user already deleted" do
    user = create(:user)
    token = AccountDeletion::CreateDeletionToken.(user)
    user.destroy!

    assert_raises(AccountDeletion::ValidateDeletionToken::InvalidTokenError) do
      AccountDeletion::ConfirmDeletion.(token)
    end
  end
end
