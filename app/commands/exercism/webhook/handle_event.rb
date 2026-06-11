class Exercism::Webhook::HandleEvent
  include Mandate

  initialize_with :payload, :signature_header

  def call
    verify_signature!

    exercism_id = parsed["exercism_id"]
    return if exercism_id.blank?

    user = User.find_by(exercism_id: exercism_id.to_s)
    return unless user

    # Re-fetch state from Exercism rather than trusting the event type — the
    # event is just a "something changed" hint. This makes us robust to
    # out-of-order delivery and stale events.
    User::Exercism::ResyncUserJob.perform_later(user)
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

  def signing_secret = Jiki.secrets.exercism_webhook_signing_secret
end
