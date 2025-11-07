# Override Devise::JWT::RevocationStrategies::Allowlist to use our custom naming
# Instead of the default :allowlisted_jwts association, we use :jwt_tokens
#
# This allows us to use semantic naming (User::JwtToken, user.jwt_tokens)
# instead of the default Allowlist naming convention.

module Devise::JwtStrategy
  # Include this module in your user model to enable JWT allowlist revocation strategy
  # with custom association naming
  def self.included(base)
    base.class_eval do
      # Create the jwt_tokens association
      has_many :jwt_tokens,
        class_name: "#{base.name}::JwtToken",
        dependent: :destroy

      # Alias allowlisted_jwts for Devise JWT compatibility
      alias_method :allowlisted_jwts, :jwt_tokens unless method_defined?(:allowlisted_jwts)

      # Called on each authenticated request to check if token is valid
      # Returns true if the token's jti exists in the allowlist
      # NOTE: This must be a class method
      def self.jwt_revoked?(payload, user)
        !user.jwt_tokens.exists?(jti: payload["jti"])
      end

      # Called when a JWT token is revoked (on logout)
      # Deletes the JWT and its associated refresh token (per-device logout)
      # NOTE: This must be a class method
      def self.revoke_jwt(payload, user)
        User::Jwt::RevokeToken.(user, payload["jti"])
      end
    end
  end

  # Called when a JWT token is dispatched (on login/signup)
  # Creates a new record in user_jwt_tokens table
  # NOTE: This is an instance method
  def on_jwt_dispatch(_token, payload)
    User::Jwt::CreateToken.(self, payload)
  end
end
