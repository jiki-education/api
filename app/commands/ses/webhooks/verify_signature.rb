# Verifies SNS message signatures for SES webhooks
#
# Implements AWS SNS signature verification as per:
# https://docs.aws.amazon.com/sns/latest/dg/sns-verify-signature-of-message.html
#
# Security checks:
# 1. SigningCertURL must be from amazonaws.com
# 2. Download and cache certificate
# 3. Verify signature matches message content

class SES::Webhooks::VerifySignature
  include Mandate

  initialize_with :message_body, :signature, :signing_cert_url, :signature_version

  def call
    return false unless valid_cert_url?
    return false unless signature_version == '1'

    verify_signature
  end

  private
  def valid_cert_url?
    return false unless signing_cert_url.present?

    uri = URI.parse(signing_cert_url)

    # Must be HTTPS
    return false unless uri.scheme == 'https'

    # Must be from amazonaws.com
    return false unless uri.host.end_with?('.amazonaws.com') || uri.host == 'amazonaws.com'

    # Must use sns path
    return false unless uri.path.start_with?('/SimpleNotificationService')

    true
  rescue URI::InvalidURIError
    false
  end

  def verify_signature
    cert = download_certificate
    public_key = cert.public_key

    # Decode the base64-encoded signature
    decoded_signature = Base64.decode64(signature)

    # Verify the signature
    public_key.verify(
      OpenSSL::Digest.new('SHA1'),
      decoded_signature,
      canonical_string
    )
  rescue StandardError
    false
  end

  memoize
  def download_certificate
    # TODO: Add certificate caching to avoid repeated downloads
    response = Net::HTTP.get_response(URI.parse(signing_cert_url))
    OpenSSL::X509::Certificate.new(response.body)
  end

  memoize
  def parsed_body
    JSON.parse(message_body)
  end

  # Build the canonical string for signature verification
  # The format depends on the message type
  def canonical_string
    if parsed_body['Type'] == 'SubscriptionConfirmation'
      subscription_confirmation_string
    else
      notification_string
    end
  end

  def subscription_confirmation_string
    parts = [
      'Message', parsed_body['Message'],
      'MessageId', parsed_body['MessageId'],
      'SubscribeURL', parsed_body['SubscribeURL'],
      'Timestamp', parsed_body['Timestamp'],
      'Token', parsed_body['Token'],
      'TopicArn', parsed_body['TopicArn'],
      'Type', parsed_body['Type']
    ]
    "#{parts.join("\n")}\n"
  end

  def notification_string
    parts = [
      'Message', parsed_body['Message'],
      'MessageId', parsed_body['MessageId']
    ]

    parts += ['Subject', parsed_body['Subject']] if parsed_body['Subject']

    parts += [
      'Timestamp', parsed_body['Timestamp'],
      'TopicArn', parsed_body['TopicArn'],
      'Type', parsed_body['Type']
    ]

    "#{parts.join("\n")}\n"
  end
end
