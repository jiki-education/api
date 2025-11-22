require "test_helper"

class SES::Webhooks::VerifySignatureTest < ActiveSupport::TestCase
  test "returns false for invalid cert URL scheme (http instead of https)" do
    result = SES::Webhooks::VerifySignature.(
      '{}',
      'signature',
      'http://sns.us-east-1.amazonaws.com/cert.pem',
      '1'
    )

    refute result
  end

  test "returns false for invalid cert URL domain (not amazonaws.com)" do
    result = SES::Webhooks::VerifySignature.(
      '{}',
      'signature',
      'https://evil.com/cert.pem',
      '1'
    )

    refute result
  end

  test "returns false for invalid cert URL path (not SimpleNotificationService)" do
    result = SES::Webhooks::VerifySignature.(
      '{}',
      'signature',
      'https://sns.us-east-1.amazonaws.com/wrong-path/cert.pem',
      '1'
    )

    refute result
  end

  test "returns false for invalid signature version" do
    result = SES::Webhooks::VerifySignature.(
      '{}',
      'signature',
      'https://sns.us-east-1.amazonaws.com/SimpleNotificationService/cert.pem',
      '2'
    )

    refute result
  end

  test "returns false for nil signing cert URL" do
    result = SES::Webhooks::VerifySignature.(
      '{}',
      'signature',
      nil,
      '1'
    )

    refute result
  end

  test "returns false for empty signing cert URL" do
    result = SES::Webhooks::VerifySignature.(
      '{}',
      'signature',
      '',
      '1'
    )

    refute result
  end

  test "returns false for malformed cert URL" do
    result = SES::Webhooks::VerifySignature.(
      '{}',
      'signature',
      'not-a-url',
      '1'
    )

    refute result
  end
end
