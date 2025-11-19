module Auth
  class CleanupExpiredTokensJob < ApplicationJob
    queue_as :default

    # Run hourly (via Solid Queue recurring jobs) to clean up expired tokens
    # This prevents the user_jwt_tokens and user_refresh_tokens tables from growing unbounded
    #
    # We use a 1-hour buffer (expires_at < 1.hour.ago) to avoid edge cases where a token
    # might be in the process of being validated when cleanup runs
    def perform
      cleanup_jwt_tokens
      cleanup_refresh_tokens
    end

    private
    def cleanup_jwt_tokens
      cutoff_time = 1.hour.ago
      deleted_count = User::JwtToken.where("expires_at < ?", cutoff_time).delete_all

      Rails.logger.info("[Auth::CleanupExpiredTokensJob] Deleted #{deleted_count} expired JWT access tokens (cutoff: #{cutoff_time})")
    end

    def cleanup_refresh_tokens
      cutoff_time = 1.hour.ago
      deleted_count = User::RefreshToken.where("expires_at < ?", cutoff_time).delete_all

      Rails.logger.info("[Auth::CleanupExpiredTokensJob] Deleted #{deleted_count} expired refresh tokens (cutoff: #{cutoff_time})")
    end
  end
end
