class User
  class GenerateHandle
    include Mandate

    initialize_with :email

    def call
      base = email.split('@').first.parameterize
      handle = base
      return handle unless User.exists?(handle:)

      # Handle collision with random hex suffix
      max_attempts = 100
      attempts = 0
      loop do
        attempts += 1
        raise "Failed to generate unique handle after #{max_attempts} attempts" if attempts > max_attempts

        handle = "#{base}-#{SecureRandom.hex(3)}"
        break unless User.exists?(handle:)
      end
      handle
    end
  end
end
