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

module ActiveSupport
  class TestCase
    include FactoryBot::Syntax::Methods
    include ActiveJob::TestHelper

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

# Authentication helpers for API testing
module AuthenticationHelper
  def setup_user(user = nil)
    @current_user = user || create(:user)
    @headers = auth_headers_for(@current_user)
  end

  def auth_headers_for(user)
    token, payload = Warden::JWTAuth::UserEncoder.new.(user, :user, nil)

    # With Allowlist strategy, we need to manually add the token to the allowlist
    # The on_jwt_dispatch callback is only triggered on actual login/signup requests
    user.jwt_tokens.create!(
      jti: payload["jti"],
      aud: payload["aud"],
      expires_at: Time.zone.at(payload["exp"].to_i)
    )

    { "Authorization" => "Bearer #{token}" }
  end

  def sign_in_as(user)
    post user_session_path, params: {
      user: { email: user.email, password: user.password }
    }, as: :json
    token = response.headers["Authorization"]&.split(" ")&.last
    { "Authorization" => "Bearer #{token}" }
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

    assert_equal expected.deep_stringify_keys, actual
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

# Base test case for API controller tests
class ApplicationControllerTest < ActionDispatch::IntegrationTest
  include AuthenticationHelper
  include JsonAssertions

  # Macro for testing authentication requirements
  def self.guard_incorrect_token!(path_helper, args: [], method: :get)
    test "#{method} #{path_helper} returns 401 with invalid token" do
      path = send(path_helper, *args)
      send(method, path, headers: { "Authorization" => "Bearer invalid" }, as: :json)

      assert_response :unauthorized
      assert_equal "unauthorized", response.parsed_body["error"]["type"]
    end

    test "#{method} #{path_helper} returns 401 without token" do
      path = send(path_helper, *args)
      send(method, path, as: :json)

      assert_response :unauthorized
      assert_equal "unauthorized", response.parsed_body["error"]["type"]
    end
  end

  # Macro for testing admin-only endpoints (includes authentication + admin checks)
  def self.guard_admin!(path_helper, args: [], method: :get)
    # First, guard against incorrect tokens (401 errors)
    guard_incorrect_token!(path_helper, args:, method:)

    # Then, guard against non-admin users (403 error)
    test "#{method} #{path_helper} returns 403 for non-admin users" do
      user = create(:user, admin: false)
      headers = auth_headers_for(user)
      path = send(path_helper, *args)

      send(method, path, headers:, as: :json)

      assert_response :forbidden
      assert_json_response({
        error: {
          type: "forbidden",
          message: "Admin access required"
        }
      })
    end
  end
end

# Include helpers in integration tests
class ActionDispatch::IntegrationTest
  include AuthenticationHelper
  include JsonAssertions
end
