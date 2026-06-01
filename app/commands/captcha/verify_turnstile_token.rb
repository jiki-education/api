module Captcha
  class VerifyTurnstileToken
    include Mandate
    include HTTParty

    SITEVERIFY_URL = "https://challenges.cloudflare.com/turnstile/v0/siteverify".freeze

    initialize_with :token, remote_ip: nil

    def call
      return false if token.blank?

      response = self.class.post(
        SITEVERIFY_URL,
        body: payload.to_json,
        headers: { "Content-Type" => "application/json" },
        timeout: 5
      )

      unless response.success?
        log_outage("siteverify returned HTTP #{response.code}")
        return true
      end

      parsed = JSON.parse(response.body)
      return true if parsed["success"]

      Rails.logger.warn("[Turnstile] verification failed: #{parsed['error-codes']}")
      false
    rescue StandardError => e
      log_outage("siteverify request raised: #{e.class}: #{e.message}")
      true
    end

    private
    def payload
      { secret:, response: token }.tap do |p|
        p[:remoteip] = remote_ip if remote_ip.present?
      end
    end

    def secret = Jiki.secrets.turnstile_secret_key

    def log_outage(message)
      Rails.logger.error("[Turnstile] #{message} - failing open")
      Sentry.capture_message("Turnstile siteverify outage: #{message}", level: :warning) if defined?(Sentry)
    end
  end
end
