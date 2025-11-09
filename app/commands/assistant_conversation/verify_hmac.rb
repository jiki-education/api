class AssistantConversation::VerifyHMAC
  include Mandate

  initialize_with :user_id, :assistant_message, :timestamp, :signature

  def call
    expected_signature = generate_hmac

    unless ActiveSupport::SecurityUtils.secure_compare(signature, expected_signature)
      raise InvalidHMACSignatureError, "HMAC signature verification failed"
    end

    true
  end

  private
  def generate_hmac
    payload = "#{user_id}:#{assistant_message}:#{timestamp}"
    OpenSSL::HMAC.hexdigest('SHA256', Jiki.secrets.hmac_secret, payload)
  end
end
