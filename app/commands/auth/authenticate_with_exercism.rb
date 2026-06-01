module Auth
  class AuthenticateWithExercism
    include Mandate

    initialize_with :code, :code_verifier

    def call
      find_by_exercism_id! || find_by_email! || create_user!
    end

    private
    def find_by_exercism_id!
      User.find_by(exercism_id:)
    end

    def find_by_email!
      User.find_by(email:)&.tap do |user|
        # Link existing account to Exercism and confirm email (Exercism verified it)
        user.update!(
          exercism_id:,
          provider: 'exercism',
          confirmed_at: Time.current
        )
      end
    end

    def create_user!
      # Prefer the user's Exercism handle. Fall back to a generated handle
      # (and retry) if it's taken on Jiki or otherwise invalid.
      handle = preferred_handle

      retries = 0
      max_retries = 5

      begin
        User.create!(
          email:,
          name:,
          exercism_id:,
          provider: 'exercism',
          confirmed_at: Time.current, # Exercism verified the email
          password: SecureRandom.hex(32), # Random password (won't be used)
          handle:
        ).tap do |user|
          User::Avatar::CopyFromUrl.defer(user, avatar_url) if avatar_url.present?
        end
      rescue ActiveRecord::RecordInvalid => e
        # Only retry if it's a handle error
        raise unless e.record.errors[:handle].any? && retries < max_retries

        retries += 1
        handle = User::GenerateHandle.(email)
        retry
      end
    end

    def preferred_handle
      exercism_handle.to_s.parameterize.presence || User::GenerateHandle.(email)
    end

    memoize
    def payload = Auth::VerifyExercismToken.(code, code_verifier)

    def exercism_id = payload['id']
    def email = payload['email']
    def name = payload['name']
    def exercism_handle = payload['handle']
    def avatar_url = payload['avatar_url']
  end
end
