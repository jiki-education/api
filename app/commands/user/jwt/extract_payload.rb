class User::Jwt::ExtractPayload
  include Mandate

  initialize_with :token_source

  def call
    return nil unless token.present?

    payload, _header = ::JWT.decode(
      token,
      Jiki.secrets.jwt_secret,
      true,
      { verify_expiration: false, algorithm: "HS256" }
    )
    payload
  rescue ::JWT::DecodeError
    nil
  end

  private
  memoize
  def token
    case token_source
    when ActionDispatch::Request
      # Extract from Authorization header
      auth_header = token_source.headers["Authorization"]
      auth_header&.sub("Bearer ", "")
    when String
      # Already a token string
      token_source
    end
  end
end
