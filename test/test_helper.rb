ENV["RAILS_ENV"] ||= "test"
require_relative "../config/environment"
require "rails/test_help"
require "mocha/minitest"
require "webmock/minitest"
require "prosopite"

# Configure WebMock to disable external connections
WebMock.disable_net_connect!(
  allow_localhost: true,
  allow: ["127.0.0.1"]
)

# Configure Prosopite for N+1 query detection in tests
Prosopite.rails_logger = true
Prosopite.raise = true # Fail tests when N+1 queries are detected

# Configure Mocha to be safe
Mocha.configure do |c|
  c.stubbing_method_unnecessarily = :prevent
  c.stubbing_non_existent_method = :prevent
  c.stubbing_non_public_method = :prevent
end

# Add Exercism-integration secrets to the test secrets OpenStruct around a
# test. They will be added to the config gem in a sibling PR; until then,
# tests that need them inject them manually.
module ExercismSecretsHelper
  EXERCISM_TEST_SECRETS = {
    exercism_api_key: "test-exercism-api-key",
    exercism_webhook_signing_secret: "test-exercism-webhook-secret"
  }.freeze

  def stub_exercism_secrets!
    EXERCISM_TEST_SECRETS.each do |k, v|
      Jiki.secrets.public_send("#{k}=", v)
    end
  end

  def unstub_exercism_secrets!
    EXERCISM_TEST_SECRETS.each_key do |k|
      Jiki.secrets.delete_field(k) if Jiki.secrets.respond_to?(k)
    end
  end
end

module PremiumTestHelpers
  def make_premium(user)
    user.data.update!(membership_type: "premium")
    user
  end

  def make_non_premium(user)
    user.data.update!(membership_type: "standard")
    user
  end
end

module ActiveSupport
  class TestCase
    include FactoryBot::Syntax::Methods
    include ActiveJob::TestHelper
    include PremiumTestHelpers
    include ExercismSecretsHelper

    # Run tests in parallel with specified workers
    parallelize(workers: :number_of_processors)

    # Use test adapter for ActiveJob tests
    setup do
      @original_adapter = ActiveJob::Base.queue_adapter
      ActiveJob::Base.queue_adapter = :test
    end

    teardown do
      ActiveJob::Base.queue_adapter = @original_adapter
    end

    # Reset I18n locale before each test to prevent locale leakage
    setup do
      I18n.locale = I18n.default_locale
    end

    teardown do
      I18n.locale = I18n.default_locale
    end

    # Setup Prosopite to scan each test for N+1 queries
    setup do
      Prosopite.scan
    end

    teardown do
      Prosopite.finish
    end

    # Add more helper methods to be used by all tests here...

    # Helper to assert a command is idempotent
    def assert_idempotent_command
      result_one = yield
      result_two = yield
      assert_equal result_one, result_two
    end
  end
end

# API error message helper
def api_error_msg(key, **options)
  I18n.t("api_errors.#{key}", **options)
end

# API success message helper
def api_msg(key, **options)
  I18n.t("api_messages.#{key}", **options)
end

# API error assertion helper - combines assert_response and assert_json_response
# Usage:
#   assert_json_error(:forbidden) # status 403, type "forbidden"
#   assert_json_error(:unauthorized, error_type: :invalid_credentials) # status 401, type "invalid_credentials"
#   assert_json_error(:unprocessable_entity, error_type: :validation_error, errors: {...})
def assert_json_error(status, error_type: nil, **extra)
  error_type ||= status
  assert_response status
  assert_json_response({
    error: { type: error_type.to_s, message: api_error_msg(error_type) }.merge(extra)
  })
end

# Authentication helpers for API testing
module AuthenticationHelper
  include Rails.application.routes.url_helpers

  def setup_user(user = nil)
    @current_user = user || create(:user)
    sign_in_user(@current_user)
  end

  # Merge a fake Turnstile token into a params hash. Use in tests that POST to
  # endpoints protected by TurnstileVerifiable (signup, login, password reset,
  # assistant_conversations create/create_user_message).
  #
  #   post user_session_path, params: with_turnstile(user: { ... }), as: :json
  def with_turnstile(params = {})
    params.merge(cf_turnstile_response: "test-turnstile-token")
  end

  # Sign in a user by posting to the session endpoint
  # This sets up the session cookie for subsequent requests
  # For admin users, completes the 2FA flow automatically
  def sign_in_user(user)
    post user_session_path, params: with_turnstile(
      user: { email: user.email, password: "password123" }
    ), as: :json

    if user.admin?
      # Admin users require 2FA - complete the flow
      User::VerifyOtp.expects(:call).with(user, "123456").returns(true)
      post auth_verify_2fa_path, params: { otp_code: "123456" }, as: :json
    end
  end
end

# JSON response assertions
module JsonAssertions
  # Helper to compare JSON structures with normalized string keys
  # Useful for comparing serializer output with actual values
  def assert_equal_json(expected, actual)
    assert_equal expected.deep_stringify_keys, actual.deep_stringify_keys
  end

  def assert_json_response(expected)
    actual = response.parsed_body

    # Automatically add meta: {events: []} to expected response if not present
    # This allows existing tests to continue working with MetaResponseWrapper
    # Tests that specifically test events should explicitly include meta in expected
    # Only add meta if the actual response has it (non-admin controllers)
    if actual.key?("meta") && expected.is_a?(Hash) && !expected.key?(:meta) && !expected.key?("meta")
      expected = expected.merge(meta: { events: [] })
    end

    # Check if expected contains any Regexp values (they can't be JSON-serialized)
    has_regex = contains_regex?(expected)

    if has_regex
      # Don't normalize if we have regexes - use deep_stringify_keys instead
      assert_json_match(expected.deep_stringify_keys, actual)
    else
      # Use JSON serialization round-trip to normalize the expected value
      # This ensures symbols become strings, just like in the actual response
      expected_normalized = JSON.parse(expected.to_json)
      assert_json_match(expected_normalized, actual)
    end
  end

  private
  # Check if a value contains any Regexp objects (recursively)
  def contains_regex?(value)
    case value
    when Regexp
      true
    when Hash
      value.values.any? { |v| contains_regex?(v) }
    when Array
      value.any? { |v| contains_regex?(v) }
    else
      false
    end
  end

  # Recursively match expected structure with actual, supporting Regex for values
  def assert_json_match(expected, actual, path = "root")
    case expected
    when Hash
      assert actual.is_a?(Hash), "Expected Hash at #{path}, got #{actual.class}"
      expected.each do |key, value|
        key_str = key.to_s
        assert actual.key?(key_str), "Missing key '#{key}' at #{path}"
        assert_json_match(value, actual[key_str], "#{path}.#{key}")
      end
      # Check for unexpected keys
      extra_keys = actual.keys - expected.keys.map(&:to_s)
      assert_empty extra_keys, "Unexpected keys at #{path}: #{extra_keys.join(', ')}"
    when Array
      assert actual.is_a?(Array), "Expected Array at #{path}, got #{actual.class}"
      assert_equal expected.length, actual.length, "Array length mismatch at #{path}"
      expected.each_with_index do |value, index|
        assert_json_match(value, actual[index], "#{path}[#{index}]")
      end
    when Regexp
      assert_match expected, actual.to_s, "Regex mismatch at #{path}"
    when nil
      assert_nil actual, "Value mismatch at #{path}"
    else
      assert_equal expected, actual, "Value mismatch at #{path}"
    end
  end

  def assert_json_structure(structure, data = response.parsed_body)
    structure.each do |key, expected_type|
      assert data.key?(key.to_s), "Expected key '#{key}' in JSON response"

      if expected_type.is_a?(Hash)
        assert_json_structure(expected_type, data[key.to_s])
      elsif expected_type.is_a?(Array) && expected_type.first.is_a?(Hash)
        data[key.to_s].each do |item|
          assert_json_structure(expected_type.first, item)
        end
      elsif expected_type
        assert data[key.to_s].is_a?(expected_type),
          "Expected '#{key}' to be #{expected_type}, got #{data[key.to_s].class}"
      end
    end
  end
end

# Default Turnstile siteverify to success for every integration test that hits
# a protected endpoint with a token. Tests that want to exercise the failure
# path can re-stub this URL with success: false.
class ActionDispatch::IntegrationTest
  setup do
    WebMock.stub_request(:post, Captcha::VerifyTurnstileToken::SITEVERIFY_URL).
      to_return(
        status: 200,
        body: { success: true }.to_json,
        headers: { "Content-Type" => "application/json" }
      )
  end
end

# Base test case for API controller tests
class ApplicationControllerTest < ActionDispatch::IntegrationTest
  include AuthenticationHelper
  include JsonAssertions

  # Macro for testing authentication requirements
  def self.guard_incorrect_token!(path_helper, args: [], method: :get)
    test "#{method} #{path_helper} returns 401 without authentication" do
      # Reset session to ensure no authentication
      reset!

      path = send(path_helper, *args)
      send(method, path, as: :json)

      assert_json_error(:unauthorized, error_type: :unauthenticated)
    end
  end

  # Macro for testing admin-only endpoints (includes authentication + admin checks)
  def self.guard_admin!(path_helper, args: [], method: :get)
    # First, guard against missing authentication (401 error)
    guard_incorrect_token!(path_helper, args:, method:)

    # Then, guard against non-admin users (403 error)
    test "#{method} #{path_helper} returns 403 for non-admin users" do
      # Reset session and sign in as non-admin user
      reset!
      user = create(:user, admin: false)
      sign_in_user(user)
      path = send(path_helper, *args)

      send(method, path, as: :json)

      assert_json_error(:forbidden)
    end
  end

  # Macro for testing dev-only endpoints (returns 404 in non-development environments)
  def self.guard_dev_only!(path_helper, args: [], method: :get)
    test "#{method} #{path_helper} returns 404 in production environment" do
      path = send(path_helper, *args)

      # Stub Rails.env to return production
      Rails.env.stubs(:development?).returns(false)

      begin
        send(method, path, as: :json)

        assert_json_error(:not_found)
      ensure
        # Clean up the stub
        Rails.env.unstub(:development?)
      end
    end
  end
end

# Include helpers in integration tests
class ActionDispatch::IntegrationTest
  include AuthenticationHelper
  include JsonAssertions
end
