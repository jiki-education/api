module Auth
  class AuthenticateWithGoogle
    include Mandate

    initialize_with :google_token

    def call
      # Try to find by google_id first
      user = User.find_by(google_id:)
      return user if user

      # Try to find by email (auto-linking)
      user = User.find_by(email:)
      if user
        # Link existing account to Google
        user.update!(
          google_id:,
          provider: 'google',
          email_verified: true
        )
        return user
      end

      # Create new user
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

    private
    memoize
    def payload = Auth::VerifyGoogleToken.(google_token)

    def google_id = payload['sub']
    def email = payload['email']
    def name = payload['name']

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
