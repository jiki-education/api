require "test_helper"

class Internal::EventsControllerTest < ApplicationControllerTest
  setup do
    setup_user
  end

  guard_incorrect_token! :internal_events_path, method: :post

  test "POST create defers Analytics::TrackEvent for allowed event with permitted properties" do
    lesson = create(:lesson, :exercise, slug: "intro-to-loops")

    Analytics::TrackEvent.expects(:defer).with(
      @current_user,
      "premium_modal_shown",
      properties: {
        "trigger" => "upgrade_cta_nav",
        "context_type" => "lesson",
        "context_slug" => "intro-to-loops",
        "context_id" => lesson.id
      }
    )

    post internal_events_path, params: {
      event: "premium_modal_shown",
      properties: { trigger: "upgrade_cta_nav", context_type: "lesson", context_slug: "intro-to-loops" }
    }, as: :json

    assert_response :no_content
  end

  test "POST create materializes context_id for challenges" do
    challenge = create(:challenge, slug: "todo-list")

    Analytics::TrackEvent.expects(:defer).with(
      @current_user,
      "premium_feature_blocked",
      properties: {
        "feature" => "challenges_page",
        "context_type" => "challenge",
        "context_slug" => "todo-list",
        "context_id" => challenge.id
      }
    )

    post internal_events_path, params: {
      event: "premium_feature_blocked",
      properties: { feature: "challenges_page", context_type: "challenge", context_slug: "todo-list" }
    }, as: :json

    assert_response :no_content
  end

  test "POST create omits context_id when slug not found" do
    Analytics::TrackEvent.expects(:defer).with(
      @current_user,
      "premium_modal_shown",
      properties: {
        "trigger" => "upgrade_cta_nav",
        "context_type" => "lesson",
        "context_slug" => "does-not-exist"
      }
    )

    post internal_events_path, params: {
      event: "premium_modal_shown",
      properties: { trigger: "upgrade_cta_nav", context_type: "lesson", context_slug: "does-not-exist" }
    }, as: :json

    assert_response :no_content
  end

  test "POST create omits context_id for unknown context_type" do
    Analytics::TrackEvent.expects(:defer).with(
      @current_user,
      "premium_modal_shown",
      properties: {
        "trigger" => "upgrade_cta_nav",
        "context_type" => "unknown",
        "context_slug" => "whatever"
      }
    )

    post internal_events_path, params: {
      event: "premium_modal_shown",
      properties: { trigger: "upgrade_cta_nav", context_type: "unknown", context_slug: "whatever" }
    }, as: :json

    assert_response :no_content
  end

  test "POST create works with no context" do
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

  test "POST create passes through context_uuid without enrichment for episode" do
    Analytics::TrackEvent.expects(:defer).with(
      @current_user,
      "premium_modal_shown",
      properties: {
        "trigger" => "locked_episode",
        "context_type" => "episode",
        "context_uuid" => "abc-123-def"
      }
    )

    post internal_events_path, params: {
      event: "premium_modal_shown",
      properties: { trigger: "locked_episode", context_type: "episode", context_uuid: "abc-123-def" }
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
      properties: { trigger: "upgrade_cta_nav", email: "evil@example.com", admin: true }
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
  # LEGACY: "project" is the pre-rename context_type. Delete this test
  # alongside the legacy projects endpoints.
  test "POST create materializes context_id for the legacy project context_type" do
    challenge = create(:challenge, slug: "todo-list")

    Analytics::TrackEvent.expects(:defer).with(
      @current_user,
      "premium_feature_blocked",
      properties: {
        "feature" => "challenges_page",
        "context_type" => "project",
        "context_slug" => "todo-list",
        "context_id" => challenge.id
      }
    )

    post internal_events_path, params: {
      event: "premium_feature_blocked",
      properties: { feature: "challenges_page", context_type: "project", context_slug: "todo-list" }
    }, as: :json

    assert_response :no_content
  end
end
