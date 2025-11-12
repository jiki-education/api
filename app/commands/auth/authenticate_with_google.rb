module Auth
  class AuthenticateWithGoogle
    include Mandate

    initialize_with :google_token

    def call
      find_by_google_id! || find_by_email! || create_user!
    end

    private
    memoize
    def payload = Auth::VerifyGoogleToken.(google_token)

    def google_id = payload['sub']
    def email = payload['email']
    def name = payload['name']

    def find_by_google_id!
      User.find_by(google_id:)
    end

    def find_by_email!
      user = User.find_by(email:)
      return unless user

      # Link existing account to Google
      user.update!(
        google_id:,
        provider: 'google',
        email_verified: true
      )
      user
    end

    def create_user!
      User.create!(
        email:,
        name:,
        google_id:,
        provider: 'google',
        email_verified: true,
        password: SecureRandom.hex(32), # Random password (won't be used)
        handle: generate_handle!(email)
      )
    end

    def generate_handle!(email)
      base = email.split('@').first.parameterize
      handle = base
      counter = 1

      # Fetch all existing handles with this base in one query to avoid N+1
      existing_handles = User.where("handle LIKE ?", "#{base}%").pluck(:handle).to_set

      while existing_handles.include?(handle)
        handle = "#{base}#{counter}"
        counter += 1
      end

      handle
    end
  end
end
