require "test_helper"

# Test controller for MetaResponseWrapper concern
class TestMetaWrapperController < ApplicationController
  def simple_response
    render json: { lesson: { slug: "test" } }
  end

  def response_with_existing_meta
    render json: { results: [], meta: { current_page: 1, total_pages: 5 } }
  end

  def empty_response
    render json: {}
  end

  def error_response
    render json: { error: { type: "not_found", message: "Not found" } }, status: :not_found
  end
end

# Test admin controller that should skip wrapping
class TestAdminController < Admin::BaseController
  def admin_response
    render json: { user: { id: 1 } }
  end
end

class MetaResponseWrapperTest < ActionDispatch::IntegrationTest
  setup do
    setup_user
    Current.reset

    # Save original method to restore later
    @original_simple_response = TestMetaWrapperController.instance_method(:simple_response)

    # Add test routes
    Rails.application.routes.draw do
      get "/test/simple" => "test_meta_wrapper#simple_response"
      get "/test/with_meta" => "test_meta_wrapper#response_with_existing_meta"
      get "/test/empty" => "test_meta_wrapper#empty_response"
      get "/test/error" => "test_meta_wrapper#error_response"
      get "/test/admin" => "test_admin#admin_response"
    end
  end

  teardown do
    # Restore original routes
    Rails.application.reload_routes!
    Current.reset

    # Restore original controller method
    TestMetaWrapperController.define_method(:simple_response, @original_simple_response)
  end

  test "adds meta with empty events to simple response" do
    get "/test/simple", headers: @headers, as: :json

    assert_response :success
    assert_json_response({
      lesson: { slug: "test" },
      meta: { events: [] }
    })
  end

  test "adds meta with events when Current.events has data" do
    # Simulate adding events during request
    TestMetaWrapperController.class_eval do
      def simple_response
        Current.add_event(:lesson_completed, { lesson_slug: "test" })
        Current.add_event(:project_unlocked, { project_slug: "calculator" })
        render json: { lesson: { slug: "test" } }
      end
    end

    get "/test/simple", headers: @headers, as: :json

    assert_response :success
    json = response.parsed_body

    assert_equal "test", json["lesson"]["slug"]
    assert_equal 2, json["meta"]["events"].size

    assert_equal "lesson_completed", json["meta"]["events"][0]["type"]
    assert_equal({ "lesson_slug" => "test" }, json["meta"]["events"][0]["data"])

    assert_equal "project_unlocked", json["meta"]["events"][1]["type"]
    assert_equal({ "project_slug" => "calculator" }, json["meta"]["events"][1]["data"])
  end

  test "merges events into existing meta" do
    get "/test/with_meta", headers: @headers, as: :json

    assert_response :success
    assert_json_response({
      results: [],
      meta: {
        current_page: 1,
        total_pages: 5,
        events: []
      }
    })
  end

  test "adds meta to empty response" do
    get "/test/empty", headers: @headers, as: :json

    assert_response :success
    assert_json_response({
      meta: { events: [] }
    })
  end

  test "adds meta to error responses" do
    get "/test/error", headers: @headers, as: :json

    assert_response :not_found
    assert_json_response({
      error: { type: "not_found", message: "Not found" },
      meta: { events: [] }
    })
  end

  test "skips wrapping for admin controllers" do
    # Make user an admin to pass authorization
    @current_user.update!(admin: true)

    get "/test/admin", headers: @headers, as: :json

    assert_response :success
    assert_json_response({
      user: { id: 1 }
    })

    # Verify meta key is NOT present
    refute response.parsed_body.key?("meta"), "Admin response should not include meta key"
  end

  test "Current.events automatically resets between requests" do
    # First request adds events
    TestMetaWrapperController.class_eval do
      def simple_response
        Current.add_event(:first_event, { value: 1 })
        render json: { lesson: { slug: "test" } }
      end
    end

    get "/test/simple", headers: @headers, as: :json
    first_response = response.parsed_body

    assert_equal 1, first_response["meta"]["events"].size
    assert_equal "first_event", first_response["meta"]["events"][0]["type"]

    # Second request should have no events (automatic reset)
    TestMetaWrapperController.class_eval do
      def simple_response
        # Don't add any events
        render json: { lesson: { slug: "test2" } }
      end
    end

    get "/test/simple", headers: @headers, as: :json
    second_response = response.parsed_body

    assert_equal 0, second_response["meta"]["events"].size
  end
end
