class Exercism::Webhook::HandleEvent
  include Mandate

  HANDLERS = {
    "insider.activated" => "Exercism::Webhook::InsiderActivated",
    "insider.deactivated" => "Exercism::Webhook::InsiderDeactivated"
  }.freeze

  initialize_with :payload, :signature_header

  def call
    verify_signature!
    handler.constantize.(parsed)
  end

  private
  def verify_signature!
    expected = "sha256=#{OpenSSL::HMAC.hexdigest('SHA256', signing_secret, payload)}"
    received = signature_header.to_s

    return if ActiveSupport::SecurityUtils.secure_compare(expected, received)

    raise InvalidExercismWebhookSignatureError, "Exercism webhook signature mismatch"
  end

  memoize
  def parsed = JSON.parse(payload)

  def handler
    HANDLERS[parsed["event"]] or
      raise InvalidExercismWebhookEventError, "Unknown event: #{parsed['event']}"
  end

  def signing_secret = Jiki.secrets.exercism_webhook_signing_secret
end
