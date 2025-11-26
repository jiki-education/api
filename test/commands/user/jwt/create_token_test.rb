require "test_helper"

class User::Jwt::CreateTokenTest < ActiveSupport::TestCase
  test "creates JWT token from payload" do
    user = create(:user)

    exp = 1.hour.from_now
    payload = {
      "jti" => SecureRandom.uuid,
      "exp" => exp.to_i
    }

    jwt_token = User::Jwt::CreateToken.(user, payload)

    refute_nil jwt_token
    assert jwt_token.persisted?
    assert_equal user.id, jwt_token.user_id
    assert_equal payload["jti"], jwt_token.jti
    assert_nil jwt_token.aud # aud is no longer stored in JWT tokens
    assert_in_delta exp, jwt_token.expires_at, 1.second
  end

  test "sets Current.jwt_record_id for later linking" do
    user = create(:user)

    payload = {
      "jti" => SecureRandom.uuid,
      "exp" => 1.hour.from_now.to_i
    }

    jwt_token = User::Jwt::CreateToken.(user, payload)

    assert_equal jwt_token.id, Current.jwt_record_id
  end

  test "creates JWT with nil aud if not in payload" do
    user = create(:user)

    payload = {
      "jti" => SecureRandom.uuid,
      "exp" => 1.hour.from_now.to_i
    }

    jwt_token = User::Jwt::CreateToken.(user, payload)

    assert_nil jwt_token.aud
  end

  test "requires jti and exp in payload" do
    user = create(:user)

    payload = {
      # Missing jti and exp
    }

    assert_raises(ActiveRecord::RecordInvalid) do
      User::Jwt::CreateToken.(user, payload)
    end
  end
end
