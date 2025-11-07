class User::Jwt::RevokeToken
  include Mandate

  initialize_with :user, :jti

  def call
    return unless jwt_record

    # Store refresh token reference BEFORE deleting JWT
    refresh_token = jwt_record.refresh_token

    # Delete the JWT first (to avoid foreign key constraint)
    jwt_record.destroy

    # Then delete the associated refresh token (per-device logout)
    refresh_token&.destroy
  end

  private
  memoize
  def jwt_record = user.jwt_tokens.find_by(jti: jti)
end
