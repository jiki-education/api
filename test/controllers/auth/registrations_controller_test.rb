require "test_helper"

class Auth::RegistrationsControllerTest < ApplicationControllerTest
  setup do
    create(:course, slug: "coding-fundamentals")
  end

  test "POST signup creates a new user with valid params" do
    assert_difference("User.count", 1) do
      post user_registration_path, params: {
        user: {
          email: "newuser@example.com",
          password: "password123",
          password_confirmation: "password123",
          name: "New User",
          handle: "newuser"
        }
      }, as: :json
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
    post user_registration_path, params: {
      user: {
        email: "newuser@example.com",
        password: "password123",
        password_confirmation: "password123"
      }
    }, as: :json

    assert_response :created

    # User should not be signed in - accessing authenticated endpoint should fail
    get internal_me_path, as: :json
    assert_response :unauthorized
  end

  test "POST signup sends confirmation email" do
    assert_difference "ActionMailer::Base.deliveries.size", 1 do
      post user_registration_path, params: {
        user: {
          email: "newuser@example.com",
          password: "password123",
          password_confirmation: "password123"
        }
      }, as: :json
    end

    assert_response :created

    email = ActionMailer::Base.deliveries.last
    assert_equal ["newuser@example.com"], email.to
    assert_includes email.subject.downcase, "confirm"
  end

  test "POST signup calls User::Bootstrap on successful registration" do
    assert_enqueued_with(
      job: MandateJob,
      args: ->(args) { args[0] == "User::SendWelcomeEmail" },
      queue: "mailers"
    ) do
      post user_registration_path, params: {
        user: {
          email: "bootstrap@example.com",
          password: "password123",
          password_confirmation: "password123",
          name: "Bootstrap User",
          handle: "bootstrapuser"
        }
      }, as: :json
    end

    assert_response :created
  end

  test "POST signup does not call User::Bootstrap on failed registration" do
    assert_no_enqueued_jobs do
      post user_registration_path, params: {
        user: {
          email: "invalid-email",
          password: "password123",
          password_confirmation: "password123",
          name: "Invalid User",
          handle: "invaliduser"
        }
      }, as: :json
    end

    assert_response :unprocessable_entity
  end

  test "POST signup returns error with invalid email" do
    assert_no_difference("User.count") do
      post user_registration_path, params: {
        user: {
          email: "invalid-email",
          password: "password123",
          password_confirmation: "password123",
          name: "New User",
          handle: "newuser"
        }
      }, as: :json
    end

    assert_response :unprocessable_entity

    json = response.parsed_body
    assert_equal "validation_error", json["error"]["type"]
    assert_equal "Validation failed", json["error"]["message"]
    assert json["error"]["errors"]["email"].present?
  end

  test "POST signup returns error with password mismatch" do
    assert_no_difference("User.count") do
      post user_registration_path, params: {
        user: {
          email: "newuser@example.com",
          password: "password123",
          password_confirmation: "different123",
          name: "New User",
          handle: "newuser"
        }
      }, as: :json
    end

    assert_response :unprocessable_entity

    json = response.parsed_body
    assert_equal "validation_error", json["error"]["type"]
    assert json["error"]["errors"]["password_confirmation"].present?
  end

  test "POST signup returns error with duplicate email" do
    create(:user, email: "existing@example.com")

    assert_no_difference("User.count") do
      post user_registration_path, params: {
        user: {
          email: "existing@example.com",
          password: "password123",
          password_confirmation: "password123",
          name: "New User",
          handle: "newuser"
        }
      }, as: :json
    end

    assert_response :unprocessable_entity

    json = response.parsed_body
    assert_equal "validation_error", json["error"]["type"]
    assert json["error"]["errors"]["email"].present?
  end

  test "POST signup returns error with short password" do
    assert_no_difference("User.count") do
      post user_registration_path, params: {
        user: {
          email: "newuser@example.com",
          password: "short",
          password_confirmation: "short",
          name: "New User",
          handle: "newuser"
        }
      }, as: :json
    end

    assert_response :unprocessable_entity

    json = response.parsed_body
    assert_equal "validation_error", json["error"]["type"]
    assert json["error"]["errors"]["password"].present?
  end

  test "POST signup auto-generates handle from email when not provided" do
    assert_difference("User.count", 1) do
      post user_registration_path, params: {
        user: {
          email: "john.doe@example.com",
          password: "password123"
        }
      }, as: :json
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
    post user_registration_path, params: {
      user: {
        email: "john.doe@example.com",
        password: "password123",
        handle: "custom-handle"
      }
    }, as: :json

    assert_response :created

    user = User.last
    assert_equal "custom-handle", user.handle

    # Response only includes email for unconfirmed users
    json = response.parsed_body
    refute json["user"]["email_confirmed"]
  end

  test "POST signup handles collision by appending random hex suffix" do
    create(:user, email: "john@other.com", handle: "john-doe")

    post user_registration_path, params: {
      user: {
        email: "john.doe@example.com",
        password: "password123"
      }
    }, as: :json

    assert_response :created

    user = User.last
    assert_match(/\Ajohn-doe-[a-f0-9]{6}\z/, user.handle)
  end
end
