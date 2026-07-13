require "test_helper"

class Auth::RegistrationsControllerTest < ApplicationControllerTest
  setup do
    create(:course, slug: "coding-fundamentals")
  end

  test "POST signup creates a new user with valid params" do
    assert_difference("User.count", 1) do
      post user_registration_path, params: with_turnstile(
        user: {
          email: "newuser@example.com",
          password: "password123",
          password_confirmation: "password123",
          name: "New User",
          handle: "newuser"
        }
      ), as: :json
    end

    assert_response :created

    json = response.parsed_body
    assert_equal "newuser@example.com", json["user"]["email"]
    refute json["user"]["email_confirmed"]
    # Unconfirmed users only get email and email_confirmed in response
    assert_nil json["user"]["name"]
    assert_nil json["user"]["handle"]
  end

  test "POST signup does not create a session for unconfirmed user" do
    post user_registration_path, params: with_turnstile(
      user: {
        email: "newuser@example.com",
        password: "password123",
        password_confirmation: "password123"
      }
    ), as: :json

    assert_response :created

    # User should not be signed in - accessing authenticated endpoint should fail
    get internal_me_path, as: :json
    assert_response :unauthorized
  end

  test "POST signup sends confirmation email" do
    # Confirmation mail is delivered asynchronously (deliver_later), so run the
    # enqueued job to assert it actually goes out.
    assert_difference "ActionMailer::Base.deliveries.size", 1 do
      perform_enqueued_jobs do
        post user_registration_path, params: with_turnstile(
          user: {
            email: "newuser@example.com",
            password: "password123",
            password_confirmation: "password123"
          }
        ), as: :json
      end
    end

    assert_response :created

    email = ActionMailer::Base.deliveries.last
    assert_equal ["newuser@example.com"], email.to
    assert_includes email.subject.downcase, "confirm"
  end

  test "POST signup calls User::Bootstrap on successful registration" do
    User::Bootstrap.expects(:call).with do |user, provider, **|
      user.email == "bootstrap@example.com" && provider == "email"
    end

    post user_registration_path, params: with_turnstile(
      user: {
        email: "bootstrap@example.com",
        password: "password123",
        password_confirmation: "password123",
        name: "Bootstrap User",
        handle: "bootstrapuser"
      }
    ), as: :json

    assert_response :created
  end

  test "POST signup forwards CF-IPCountry header to User::Bootstrap" do
    User::Bootstrap.expects(:call).with(
      instance_of(User),
      "email",
      has_entries(country_code: "JP")
    )

    post user_registration_path,
      params: with_turnstile(
        user: {
          email: "jp@example.com",
          password: "password123",
          password_confirmation: "password123",
          name: "JP User",
          handle: "jpuser"
        }
      ),
      headers: { "CF-IPCountry" => "JP" },
      as: :json

    assert_response :created
  end

  test "POST signup persists country_code from CF-IPCountry header" do
    post user_registration_path,
      params: with_turnstile(
        user: {
          email: "jp2@example.com",
          password: "password123",
          password_confirmation: "password123",
          name: "JP User",
          handle: "jpuser2"
        }
      ),
      headers: { "CF-IPCountry" => "JP" },
      as: :json

    assert_response :created
    assert_equal "JP", User.find_by(email: "jp2@example.com").data.country_code
  end

  test "POST signup forwards Accept-Language header to User::Bootstrap" do
    User::Bootstrap.expects(:call).with(
      instance_of(User),
      "email",
      has_entries(accept_language: "hu, en;q=0.8")
    )

    post user_registration_path,
      params: with_turnstile(
        user: {
          email: "hu@example.com",
          password: "password123",
          password_confirmation: "password123",
          name: "HU User",
          handle: "huuser"
        }
      ),
      headers: { "Accept-Language" => "hu, en;q=0.8" },
      as: :json

    assert_response :created
  end

  test "POST signup persists locales from Accept-Language header" do
    post user_registration_path,
      params: with_turnstile(
        user: {
          email: "hu2@example.com",
          password: "password123",
          password_confirmation: "password123",
          name: "HU User",
          handle: "huuser2"
        }
      ),
      headers: { "Accept-Language" => "hu, en;q=0.8" },
      as: :json

    assert_response :created

    user = User.find_by(email: "hu2@example.com")
    assert_equal %w[hu en], user.data.locales
    assert_nil user.data.explicit_locale
  end

  test "POST signup sets explicit_locale from locale param" do
    post user_registration_path,
      params: with_turnstile(
        user: {
          email: "hu3@example.com",
          password: "password123",
          password_confirmation: "password123",
          name: "HU User",
          handle: "huuser3",
          locale: "hu"
        }
      ),
      as: :json

    assert_response :created
    assert_equal "hu", User.find_by(email: "hu3@example.com").data.explicit_locale
  end

  test "POST signup ignores an unsupported locale param" do
    post user_registration_path,
      params: with_turnstile(
        user: {
          email: "de@example.com",
          password: "password123",
          password_confirmation: "password123",
          name: "DE User",
          handle: "deuser",
          locale: "de"
        }
      ),
      as: :json

    assert_response :created
    assert_nil User.find_by(email: "de@example.com").data.explicit_locale
  end

  test "POST signup does not call User::Bootstrap on failed registration" do
    assert_no_enqueued_jobs do
      post user_registration_path, params: with_turnstile(
        user: {
          email: "invalid-email",
          password: "password123",
          password_confirmation: "password123",
          name: "Invalid User",
          handle: "invaliduser"
        }
      ), as: :json
    end

    assert_response :unprocessable_entity
  end

  test "POST signup returns error with invalid email" do
    assert_no_difference("User.count") do
      post user_registration_path, params: with_turnstile(
        user: {
          email: "invalid-email",
          password: "password123",
          password_confirmation: "password123",
          name: "New User",
          handle: "newuser"
        }
      ), as: :json
    end

    assert_response :unprocessable_entity

    json = response.parsed_body
    assert_equal "validation_error", json["error"]["type"]
    assert_equal "Validation failed", json["error"]["message"]
    assert json["error"]["errors"]["email"].present?
  end

  test "POST signup does not report 422 to Sentry for auth namespace" do
    Sentry.expects(:capture_message).never

    post user_registration_path, params: with_turnstile(
      user: {
        email: "invalid-email",
        password: "password123",
        password_confirmation: "password123",
        name: "New User",
        handle: "newuser"
      }
    ), as: :json

    assert_response :unprocessable_entity
  end

  test "POST signup returns error with password mismatch" do
    assert_no_difference("User.count") do
      post user_registration_path, params: with_turnstile(
        user: {
          email: "newuser@example.com",
          password: "password123",
          password_confirmation: "different123",
          name: "New User",
          handle: "newuser"
        }
      ), as: :json
    end

    assert_response :unprocessable_entity

    json = response.parsed_body
    assert_equal "validation_error", json["error"]["type"]
    assert json["error"]["errors"]["password_confirmation"].present?
  end

  test "POST signup returns error with duplicate email" do
    create(:user, email: "existing@example.com")

    assert_no_difference("User.count") do
      post user_registration_path, params: with_turnstile(
        user: {
          email: "existing@example.com",
          password: "password123",
          password_confirmation: "password123",
          name: "New User",
          handle: "newuser"
        }
      ), as: :json
    end

    assert_response :unprocessable_entity

    json = response.parsed_body
    assert_equal "validation_error", json["error"]["type"]
    assert json["error"]["errors"]["email"].present?
  end

  test "POST signup returns error with short password" do
    assert_no_difference("User.count") do
      post user_registration_path, params: with_turnstile(
        user: {
          email: "newuser@example.com",
          password: "short",
          password_confirmation: "short",
          name: "New User",
          handle: "newuser"
        }
      ), as: :json
    end

    assert_response :unprocessable_entity

    json = response.parsed_body
    assert_equal "validation_error", json["error"]["type"]
    assert json["error"]["errors"]["password"].present?
  end

  test "POST signup auto-generates handle from email when not provided" do
    assert_difference("User.count", 1) do
      post user_registration_path, params: with_turnstile(
        user: {
          email: "john.doe@example.com",
          password: "password123"
        }
      ), as: :json
    end

    assert_response :created

    user = User.last
    assert_equal "john-doe", user.handle
    assert_nil user.name

    # Response only includes email for unconfirmed users
    json = response.parsed_body
    assert_equal "john.doe@example.com", json["user"]["email"]
    refute json["user"]["email_confirmed"]
  end

  test "POST signup accepts user-provided handle when provided" do
    post user_registration_path, params: with_turnstile(
      user: {
        email: "john.doe@example.com",
        password: "password123",
        handle: "custom-handle"
      }
    ), as: :json

    assert_response :created

    user = User.last
    assert_equal "custom-handle", user.handle

    # Response only includes email for unconfirmed users
    json = response.parsed_body
    refute json["user"]["email_confirmed"]
  end

  test "POST signup handles collision by appending random hex suffix" do
    create(:user, email: "john@other.com", handle: "john-doe")

    post user_registration_path, params: with_turnstile(
      user: {
        email: "john.doe@example.com",
        password: "password123"
      }
    ), as: :json

    assert_response :created

    user = User.last
    assert_match(/\Ajohn-doe-[a-f0-9]{6}\z/, user.handle)
  end

  test "POST signup returns 403 invalid_captcha when Turnstile token missing" do
    assert_no_difference("User.count") do
      post user_registration_path, params: {
        user: {
          email: "newuser@example.com",
          password: "password123"
        }
      }, as: :json
    end

    assert_json_error(:forbidden, error_type: :invalid_captcha)
  end

  test "POST signup returns 403 invalid_captcha when Turnstile siteverify rejects token" do
    WebMock.stub_request(:post, Captcha::VerifyTurnstileToken::SITEVERIFY_URL).
      to_return(status: 200, body: { success: false, "error-codes" => ["invalid-input-response"] }.to_json)

    assert_no_difference("User.count") do
      post user_registration_path, params: with_turnstile(
        user: {
          email: "newuser@example.com",
          password: "password123"
        }
      ), as: :json
    end

    assert_json_error(:forbidden, error_type: :invalid_captcha)
  end
end
