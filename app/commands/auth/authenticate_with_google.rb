module Auth
  class AuthenticateWithGoogle
    include Mandate

    initialize_with :google_token

    def call
      find_by_google_id! || find_by_email! || create_user!
    end

    private
    def find_by_google_id!
      User.find_by(google_id:)
    end

    def find_by_email!
      User.find_by(email:)&.tap do |user|
        # Link existing account to Google and confirm email (Google verified it)
        user.update!(
          google_id:,
          provider: 'google',
          confirmed_at: Time.current
        )
      end
    end

    def create_user!
      # Retry up to 5 times in case of handle uniqueness constraint violation
      retries = 0
      max_retries = 5

      begin
        User.create!(
          email:,
          name:,
          google_id:,
          provider: 'google',
          confirmed_at: Time.current, # Google verified the email
          password: SecureRandom.hex(32), # Random password (won't be used)
          handle: User::GenerateHandle.(email)
        )
      rescue ActiveRecord::RecordInvalid => e
        # Only retry if it's a handle uniqueness error
        raise unless e.record.errors[:handle].any? && retries < max_retries

        retries += 1
        retry
      end
    end

    memoize
    def payload = Auth::VerifyGoogleToken.(google_token)

    def google_id = payload['sub']
    def email = payload['email']
    def name = payload['name']
  end
end
