class User::Jwt::CreateRefreshToken
  include Mandate

  initialize_with :user

  def call
    # Create the refresh token (User-Agent already set in Current by ApplicationController)
    user.refresh_tokens.create!(
      aud: Current.user_agent,
      expires_at: 30.days.from_now
    ).tap do |refresh_token|
      # Link the JWT record to this refresh token
      user.jwt_tokens.where(id: Current.jwt_record_id).update_all(refresh_token_id: refresh_token.id) if Current.jwt_record_id.present?
    end
  end
end
