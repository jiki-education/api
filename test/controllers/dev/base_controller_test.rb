require "test_helper"

class Dev::BaseControllerTest < ApplicationControllerTest
  # Create a test controller to test the base controller functionality
  class TestController < Dev::BaseController
    def test_action
      render json: { success: true }
    end
  end

  setup do
    # Add test route temporarily
    Rails.application.routes.draw do
      namespace :dev do
        get "test", to: "base_controller_test/test#test_action"
      end
    end
  end

  teardown do
    # Reload the original routes
    Rails.application.reload_routes!
  end

  test "returns 404 in production environment" do
    Rails.env.stubs(:development?).returns(false)

    begin
      get "/dev/test", as: :json

      assert_json_error(:not_found)
    ensure
      Rails.env.unstub(:development?)
    end
  end

  test "allows access in development environment" do
    Rails.env.stubs(:development?).returns(true)

    begin
      get "/dev/test", as: :json

      assert_response :success
      assert_json_response({ success: true })
    ensure
      Rails.env.unstub(:development?)
    end
  end
end
