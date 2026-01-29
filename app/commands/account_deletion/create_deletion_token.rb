class AccountDeletion::CreateDeletionToken
  include Mandate

  EXPIRY_DURATION = 1.hour

  initialize_with :user

  def call
    payload = {
      sub: user.id,
      purpose: "account_deletion",
      exp: EXPIRY_DURATION.from_now.to_i,
      iat: Time.current.to_i
    }

    JWT.encode(payload, Jiki.secrets.jwt_secret, 'HS256')
  end
end
