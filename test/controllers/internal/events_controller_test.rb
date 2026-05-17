require "test_helper"

class Internal::EventsControllerTest < ApplicationControllerTest
  setup do
    setup_user
  end

  guard_incorrect_token! :internal_events_path, method: :post

  test "POST create defers Analytics::TrackEvent for allowed event with permitted properties" do
    Analytics::TrackEvent.expects(:defer).with(
      @current_user,
      "premium_modal_shown",
      properties: { "trigger" => "upgrade_cta_nav", "context_type" => "Lesson", "context_id" => 5 }
    )

    post internal_events_path, params: {
      event: "premium_modal_shown",
      properties: { trigger: "upgrade_cta_nav", context_type: "Lesson", context_id: 5 }
    }, as: :json

    assert_response :no_content
  end

  test "POST create accepts premium_feature_blocked" do
    Analytics::TrackEvent.expects(:defer).with(
      @current_user,
      "premium_feature_blocked",
      properties: { "feature" => "assistant_tab" }
    )

    post internal_events_path, params: {
      event: "premium_feature_blocked",
      properties: { feature: "assistant_tab" }
    }, as: :json

    assert_response :no_content
  end

  test "POST create strips unpermitted properties" do
    Analytics::TrackEvent.expects(:defer).with(
      @current_user,
      "premium_modal_shown",
      properties: { "trigger" => "upgrade_cta_nav" }
    )

    post internal_events_path, params: {
      event: "premium_modal_shown",
      properties: { trigger: "upgrade_cta_nav", email: "evil@example.com" }
    }, as: :json

    assert_response :no_content
  end

  test "POST create rejects unknown event" do
    Analytics::TrackEvent.expects(:defer).never

    post internal_events_path, params: {
      event: "made_up_event",
      properties: {}
    }, as: :json

    assert_json_error(:unprocessable_entity, error_type: :invalid_event)
  end

  test "POST create works with no properties param" do
    Analytics::TrackEvent.expects(:defer).with(
      @current_user,
      "premium_modal_shown",
      properties: {}
    )

    post internal_events_path, params: { event: "premium_modal_shown" }, as: :json

    assert_response :no_content
  end
end
