module Auth
  class AuthenticateWithOauth
    include Mandate

    # The payload is a normalized identity hash produced by the provider's
    # Verify*Token command: id, email, name, handle (optional),
    # avatar_url (optional).
    initialize_with :provider, :payload

    def call
      find_by_provider_id! || find_by_email! || create_user!
    end

    private
    def find_by_provider_id!
      User.find_by(id_column => id)
    end

    def find_by_email!
      User.find_by(email:)&.tap do |user|
        # Link existing account to the provider and confirm email
        # (the provider has verified it)
        user.update!(
          id_column => id,
          confirmed_at: Time.current
        )
      end
    end

    def create_user!
      handle = initial_handle

      retries = 0
      max_retries = 5

      begin
        User.create!(
          id_column => id,
          email:,
          name:,
          confirmed_at: Time.current, # The provider verified the email
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

    # Prefer the handle the provider gave us (e.g. the user's Exercism handle).
    # Fall back to generating one from their email.
    def initial_handle
      preferred_handle.to_s.parameterize.presence || User::GenerateHandle.(email)
    end

    def id_column = :"#{provider}_id"

    def id = payload['id']
    def email = payload['email']
    def name = payload['name']
    def preferred_handle = payload['handle']
    def avatar_url = payload['avatar_url']
  end
end
