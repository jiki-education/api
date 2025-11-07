class User::Jwt::CreateToken
  include Mandate

  initialize_with :user, :payload

  def call
    user.jwt_tokens.create!(
      jti: payload["jti"],
      aud: payload["aud"],
      expires_at: Time.zone.at(payload["exp"].to_i)
    ).tap do |jwt_record|
      # Store JWT record ID so it can be linked to refresh token later
      Current.jwt_record_id = jwt_record.id
    end
  end
end
