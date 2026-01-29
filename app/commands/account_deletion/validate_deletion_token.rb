class AccountDeletion::ValidateDeletionToken
  class InvalidTokenError < StandardError; end
  class TokenExpiredError < StandardError; end

  include Mandate

  initialize_with :token

  def call
    decoded = JWT.decode(token, Jiki.secrets.jwt_secret, true, algorithm: 'HS256')
    payload = decoded.first

    raise InvalidTokenError unless payload["purpose"] == "account_deletion"

    user_id = payload["sub"]
    User.find(user_id)
  rescue JWT::ExpiredSignature
    raise TokenExpiredError
  rescue JWT::DecodeError, ActiveRecord::RecordNotFound
    raise InvalidTokenError
  end
end
