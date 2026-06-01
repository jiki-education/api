require "test_helper"

class Captcha::VerifyTurnstileTokenTest < ActiveSupport::TestCase
  SITEVERIFY_URL = Captcha::VerifyTurnstileToken::SITEVERIFY_URL

  test "returns true when siteverify reports success" do
    stub = stub_request(:post, SITEVERIFY_URL).
      with(body: hash_including(secret: Jiki.secrets.turnstile_secret_key, response: "good-token")).
      to_return(status: 200, body: { success: true }.to_json, headers: { "Content-Type" => "application/json" })

    assert Captcha::VerifyTurnstileToken.("good-token")
    assert_requested stub
  end

  test "includes remote_ip in payload when provided" do
    stub = stub_request(:post, SITEVERIFY_URL).
      with(body: hash_including(remoteip: "203.0.113.7")).
      to_return(status: 200, body: { success: true }.to_json)

    assert Captcha::VerifyTurnstileToken.("token", remote_ip: "203.0.113.7")
    assert_requested stub
  end

  test "omits remote_ip from payload when blank" do
    stub = stub_request(:post, SITEVERIFY_URL).
      with { |req| !JSON.parse(req.body).key?("remoteip") }.
      to_return(status: 200, body: { success: true }.to_json)

    assert Captcha::VerifyTurnstileToken.("token")
    assert_requested stub
  end

  test "returns false when token is blank without calling siteverify" do
    stub_request(:post, SITEVERIFY_URL) # no .to_return — would fail if hit

    refute Captcha::VerifyTurnstileToken.(nil)
    refute Captcha::VerifyTurnstileToken.("")
    assert_not_requested :post, SITEVERIFY_URL
  end

  test "returns false when siteverify returns success false" do
    stub_request(:post, SITEVERIFY_URL).
      to_return(status: 200, body: { success: false, "error-codes" => ["invalid-input-response"] }.to_json)

    refute Captcha::VerifyTurnstileToken.("bad-token")
  end

  test "fails open (returns true) on non-2xx response from siteverify" do
    stub_request(:post, SITEVERIFY_URL).to_return(status: 502, body: "")

    assert Captcha::VerifyTurnstileToken.("token")
  end

  test "fails open (returns true) on network error" do
    stub_request(:post, SITEVERIFY_URL).to_timeout

    assert Captcha::VerifyTurnstileToken.("token")
  end
end
