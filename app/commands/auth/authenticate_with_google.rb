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
        # Link existing account to Google
        user.update!(
          google_id:,
          provider: 'google',
          email_verified: true
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
          email_verified: true,
          password: SecureRandom.hex(32), # Random password (won't be used)
          handle: generate_handle!(email)
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

    def generate_handle!(email)
      base = email.split('@').first.parameterize

      # Start with base, then try base + random suffix
      # Random suffix reduces collision probability vs sequential counter
      handle = base

      # Check if base handle exists
      return handle unless User.exists?(handle:)

      # If base is taken, append random number
      # This reduces race condition window compared to sequential counter
      loop do
        handle = "#{base}#{SecureRandom.random_number(10_000)}"
        break unless User.exists?(handle:)
      end

      handle
    end
  end
end
