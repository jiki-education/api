require "test_helper"

class AccountDeletion::CreateDeletionTokenTest < ActiveSupport::TestCase
  test "creates deletion token with correct payload" do
    user = create(:user)

    token = AccountDeletion::CreateDeletionToken.(user)

    assert token.present?

    payload = JWT.decode(token, Jiki.secrets.jwt_secret, true, { algorithm: 'HS256' }).first
    assert_equal user.id, payload['sub']
    assert_equal "account_deletion", payload['purpose']
    assert payload['exp'].present?
    assert payload['iat'].present?
  end

  test "token expires in 1 hour" do
    user = create(:user)

    freeze_time do
      token = AccountDeletion::CreateDeletionToken.(user)

      payload = JWT.decode(token, Jiki.secrets.jwt_secret, true, { algorithm: 'HS256' }).first
      expected_exp = 1.hour.from_now.to_i

      assert_equal expected_exp, payload['exp']
    end
  end

  test "uses HS256 algorithm" do
    user = create(:user)

    token = AccountDeletion::CreateDeletionToken.(user)

    # Decoding with HS256 should work
    payload = JWT.decode(token, Jiki.secrets.jwt_secret, true, { algorithm: 'HS256' })
    assert payload.present?
  end
end
