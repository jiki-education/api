require "test_helper"

class Auth::RegistrationsControllerTest < ApplicationControllerTest
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
    assert_equal "New User", json["user"]["name"]
    assert_equal "newuser", json["user"]["handle"]
    assert_equal "standard", json["user"]["membership_type"]

    # Check JWT token in response header
    token = response.headers["Authorization"]
    assert token.present?
    assert token.start_with?("Bearer ")
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
end
