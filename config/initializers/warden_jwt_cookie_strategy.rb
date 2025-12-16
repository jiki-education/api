# Custom extension to Warden::JWTAuth::Strategy for httpOnly cookie support
# Extends JWT extraction to support both Authorization header and httpOnly cookies
#
# Supports dual authentication methods for XSS protection while maintaining compatibility.
# Priority: Authorization header (explicit) first, then httpOnly cookie (automatic).
#
# Cookie details:
# - Name: jiki_access_token
# - Domain: .jiki.io (set by Next.js frontend)
# - HttpOnly: true
# - SameSite: lax
# - Secure: true (production)

module Warden
  module JWTAuth
    class Strategy < Warden::Strategies::Base
      # Override token extraction to check Authorization header first, then cookie
      def token
        # Try Authorization header first (explicit intent)
        header_token = HeaderParser.from_env(env)
        return header_token if header_token.present?

        # Fallback to cookie (automatic)
        request = ActionDispatch::Request.new(env)
        request.cookies['jiki_access_token']
      end
    end
  end
end
