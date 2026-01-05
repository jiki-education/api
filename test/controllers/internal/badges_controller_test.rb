require "test_helper"

class Internal::BadgesControllerTest < ApplicationControllerTest
  setup do
    setup_user
  end

  # Authentication guards
  guard_incorrect_token! :internal_badges_path, method: :get
  guard_incorrect_token! :reveal_internal_badge_path, args: [1], method: :patch

  # Index action tests
  test "GET index returns all non-secret badges" do
    create(:member_badge)
    create(:maze_navigator_badge)
    create(:test_secret_badge)

    get internal_badges_path, headers: @headers, as: :json

    assert_response :success
    json = response.parsed_body
    badge_names = json["badges"].map { |b| b["name"] }
    assert_includes badge_names, "Member"
    assert_includes badge_names, "Maze Navigator"
    refute_includes badge_names, "Secret Badge"
  end

  test "GET index includes acquired secret badges" do
    secret_badge = create(:test_secret_badge)
    create(:user_acquired_badge, user: @current_user, badge: secret_badge)

    get internal_badges_path, headers: @headers, as: :json

    assert_response :success
    json = response.parsed_body
    badge_names = json["badges"].map { |b| b["name"] }
    assert_includes badge_names, "Secret Badge"
  end

  test "GET index shows correct state for locked badge" do
    create(:member_badge)

    get internal_badges_path, headers: @headers, as: :json

    assert_response :success
    json = response.parsed_body
    locked_badge = json["badges"].find { |b| b["name"] == "Member" }
    assert_equal "locked", locked_badge["state"]
    assert_nil locked_badge["unlocked_at"]
  end

  test "GET index shows correct state for unrevealed badge" do
    badge = create(:member_badge)
    create(:user_acquired_badge, user: @current_user, badge:, revealed: false)

    get internal_badges_path, headers: @headers, as: :json

    assert_response :success
    json = response.parsed_body
    unrevealed_badge = json["badges"].find { |b| b["name"] == "Member" }
    assert_equal "unrevealed", unrevealed_badge["state"]
    refute_nil unrevealed_badge["unlocked_at"]
  end

  test "GET index shows correct state for revealed badge" do
    badge = create(:maze_navigator_badge)
    create(:user_acquired_badge, :revealed, user: @current_user, badge:)

    get internal_badges_path, headers: @headers, as: :json

    assert_response :success
    json = response.parsed_body
    revealed_badge = json["badges"].find { |b| b["name"] == "Maze Navigator" }
    assert_equal "revealed", revealed_badge["state"]
    refute_nil revealed_badge["unlocked_at"]
  end

  test "GET index returns correct count of locked secret badges" do
    create(:test_secret_badge)

    get internal_badges_path, headers: @headers, as: :json

    assert_response :success
    json = response.parsed_body
    assert_equal 1, json["num_locked_secret_badges"]
  end

  test "GET index uses SerializeBadges" do
    SerializeBadges.expects(:call).with(@current_user).returns([])

    get internal_badges_path, headers: @headers, as: :json

    assert_response :success
  end

  # Reveal action tests
  test "PATCH reveal marks badge as revealed" do
    badge = create(:badge)
    acquired_badge = create(:user_acquired_badge, user: @current_user, badge:, revealed: false)

    patch reveal_internal_badge_path(badge.id), headers: @headers, as: :json

    assert_response :success
    assert acquired_badge.reload.revealed?
  end

  test "PATCH reveal returns serialized badge" do
    badge = create(:member_badge)
    create(:user_acquired_badge, user: @current_user, badge:, revealed: false)

    patch reveal_internal_badge_path(badge.id), headers: @headers, as: :json

    assert_response :success
    json = response.parsed_body
    assert_equal badge.id, json["badge"]["id"]
    assert_equal "Member", json["badge"]["name"]
    assert_equal "logo", json["badge"]["icon"]
    assert json["badge"]["revealed"]
  end

  test "PATCH reveal returns 404 when badge not found" do
    patch reveal_internal_badge_path(999), headers: @headers, as: :json

    assert_response :not_found
    assert_json_response({
      error: {
        type: "not_found",
        message: "Badge not found"
      }
    })
  end

  test "PATCH reveal returns 404 when badge belongs to different user" do
    other_user = create(:user)
    badge = create(:badge)
    create(:user_acquired_badge, user: other_user, badge:)

    patch reveal_internal_badge_path(badge.id), headers: @headers, as: :json

    assert_response :not_found
    assert_json_response({
      error: {
        type: "not_found",
        message: "Badge not found"
      }
    })
  end

  test "PATCH reveal uses User::AcquiredBadge::Reveal command" do
    badge = create(:badge)
    acquired_badge = create(:user_acquired_badge, user: @current_user, badge:)

    User::AcquiredBadge::Reveal.expects(:call).with(acquired_badge)

    patch reveal_internal_badge_path(badge.id), headers: @headers, as: :json

    assert_response :success
  end
end
