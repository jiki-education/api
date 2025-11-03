require "test_helper"

class AssistantConversation::VerifyHMACTest < ActiveSupport::TestCase
  test "returns true with valid signature" do
    user_id = 123
    assistant_message = "Try breaking it down step by step."
    timestamp = "2025-10-31T08:15:35.000Z"

    payload = "#{user_id}:#{assistant_message}:#{timestamp}"
    signature = OpenSSL::HMAC.hexdigest('SHA256', Jiki.secrets.hmac_secret, payload)

    result = AssistantConversation::VerifyHMAC.(
      user_id,
      assistant_message,
      timestamp,
      signature
    )

    assert result
  end

  test "raises InvalidHMACSignatureError with invalid signature" do
    user_id = 123
    assistant_message = "Try breaking it down step by step."
    timestamp = "2025-10-31T08:15:35.000Z"
    invalid_signature = "invalid_signature_abc123"

    error = assert_raises InvalidHMACSignatureError do
      AssistantConversation::VerifyHMAC.(
        user_id,
        assistant_message,
        timestamp,
        invalid_signature
      )
    end

    assert_match(/HMAC signature verification failed/, error.message)
  end

  test "raises InvalidHMACSignatureError when payload is modified" do
    user_id = 123
    assistant_message = "Try breaking it down step by step."
    timestamp = "2025-10-31T08:15:35.000Z"

    payload = "#{user_id}:#{assistant_message}:#{timestamp}"
    signature = OpenSSL::HMAC.hexdigest('SHA256', Jiki.secrets.hmac_secret, payload)

    # Modify the message
    modified_message = "This is a forged message"

    error = assert_raises InvalidHMACSignatureError do
      AssistantConversation::VerifyHMAC.(
        user_id,
        modified_message,
        timestamp,
        signature
      )
    end

    assert_match(/HMAC signature verification failed/, error.message)
  end
end
