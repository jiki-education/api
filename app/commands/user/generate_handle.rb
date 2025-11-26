class User
  class GenerateHandle
    include Mandate

    initialize_with :email

    def call
      return base unless User.exists?(handle: base)

      # Handle collision with random hex suffix
      max_attempts = 100
      attempts = 0
      handle = nil
      loop do
        attempts += 1
        raise "Failed to generate unique handle after #{max_attempts} attempts" if attempts > max_attempts

        handle = "#{base}-#{SecureRandom.hex(3)}"
        break unless User.exists?(handle:)
      end
      handle
    end

    memoize
    def base = email.split('@').first.parameterize
  end
end
