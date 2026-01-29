require "test_helper"

class AccountDeletion::ValidateDeletionTokenTest < ActiveSupport::TestCase
  test "returns user for valid token" do
    user = create(:user)
    token = AccountDeletion::CreateDeletionToken.(user)

    result = AccountDeletion::ValidateDeletionToken.(token)

    assert_equal user, result
  end

  test "raises InvalidTokenError for malformed token" do
    assert_raises(AccountDeletion::ValidateDeletionToken::InvalidTokenError) do
      AccountDeletion::ValidateDeletionToken.("invalid-token")
    end
  end

  test "raises InvalidTokenError for wrong purpose" do
    user = create(:user)
    payload = {
      sub: user.id,
      purpose: "other_purpose",
      exp: 1.hour.from_now.to_i,
      iat: Time.current.to_i
    }
    token = JWT.encode(payload, Jiki.secrets.jwt_secret, 'HS256')

    assert_raises(AccountDeletion::ValidateDeletionToken::InvalidTokenError) do
      AccountDeletion::ValidateDeletionToken.(token)
    end
  end

  test "raises InvalidTokenError for non-existent user" do
    payload = {
      sub: "non-existent-id",
      purpose: "account_deletion",
      exp: 1.hour.from_now.to_i,
      iat: Time.current.to_i
    }
    token = JWT.encode(payload, Jiki.secrets.jwt_secret, 'HS256')

    assert_raises(AccountDeletion::ValidateDeletionToken::InvalidTokenError) do
      AccountDeletion::ValidateDeletionToken.(token)
    end
  end

  test "raises TokenExpiredError for expired token" do
    user = create(:user)

    token = travel_to(2.hours.ago) do
      AccountDeletion::CreateDeletionToken.(user)
    end

    assert_raises(AccountDeletion::ValidateDeletionToken::TokenExpiredError) do
      AccountDeletion::ValidateDeletionToken.(token)
    end
  end

  test "raises InvalidTokenError for wrong secret" do
    user = create(:user)
    payload = {
      sub: user.id,
      purpose: "account_deletion",
      exp: 1.hour.from_now.to_i,
      iat: Time.current.to_i
    }
    token = JWT.encode(payload, "wrong-secret", 'HS256')

    assert_raises(AccountDeletion::ValidateDeletionToken::InvalidTokenError) do
      AccountDeletion::ValidateDeletionToken.(token)
    end
  end
end
