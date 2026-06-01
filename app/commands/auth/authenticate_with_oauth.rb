module Auth
  class AuthenticateWithOauth
    include Mandate

    PROVIDERS = %i[google exercism].freeze

    # token_args are passed straight through to the provider's Verify*Token
    # command, so each provider can require whatever its flow needs
    # (e.g. Google takes a code; Exercism takes a code + PKCE verifier).
    def initialize(provider, *token_args)
      @provider = provider
      @token_args = token_args
    end

    def call
      validate_provider!
      validate_payload!

      find_by_provider_id! || find_by_email! || create_user!
    end

    private
    attr_reader :provider, :token_args

    def validate_provider!
      raise ArgumentError, "Unknown OAuth provider: #{provider}" unless PROVIDERS.include?(provider)
    end

    # Guard against malformed provider payloads. Without this, a nil id
    # would make find_by_provider_id! match an arbitrary non-OAuth user.
    def validate_payload!
      raise InvalidOauthPayloadError if id.blank? || email.blank?
    end

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

    memoize
    def payload = verify_command.(*token_args)

    def verify_command = "Auth::Verify#{provider.to_s.camelize}Token".constantize

    def id_column = :"#{provider}_id"

    def id = payload['id']
    def email = payload['email']
    def name = payload['name']
    def preferred_handle = payload['handle']
    def avatar_url = payload['avatar_url']
  end
end
