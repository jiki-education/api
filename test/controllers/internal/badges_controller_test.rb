require "test_helper"

class Internal::BadgesControllerTest < ApplicationControllerTest
  setup do
    setup_user
  end

  # Authentication guards
  guard_incorrect_token! :internal_badges_path, method: :get
  guard_incorrect_token! :reveal_internal_badge_path, args: [1], method: :patch

  # Index action tests
  test "GET index returns all non-secret badges and excludes secret badges" do
    create(:member_badge)
    create(:maze_navigator_badge)
    create(:test_secret_badge)

    get internal_badges_path, as: :json

    assert_response :success
    assert_json_response({
      badges: SerializeBadges.(@current_user),
      num_locked_secret_badges: 1
    })
  end

  test "GET index includes acquired secret badges" do
    secret_badge = create(:test_secret_badge)
    create(:user_acquired_badge, user: @current_user, badge: secret_badge)

    get internal_badges_path, as: :json

    assert_response :success
    assert_json_response({
      badges: SerializeBadges.(@current_user),
      num_locked_secret_badges: 0
    })
  end

  test "GET index returns badges with correct states" do
    create(:member_badge)
    unrevealed_badge = create(:maze_navigator_badge)
    revealed_badge = create(:test_secret_badge)

    create(:user_acquired_badge, user: @current_user, badge: unrevealed_badge, revealed: false)
    create(:user_acquired_badge, :revealed, user: @current_user, badge: revealed_badge)

    get internal_badges_path, as: :json

    assert_response :success
    assert_json_response({
      badges: SerializeBadges.(@current_user),
      num_locked_secret_badges: 0
    })
  end

  test "GET index uses SerializeBadges" do
    SerializeBadges.expects(:call).with(@current_user).returns([])

    get internal_badges_path, as: :json

    assert_response :success
  end

  # Reveal action tests
  test "PATCH reveal marks badge as revealed" do
    badge = create(:badge)
    acquired_badge = create(:user_acquired_badge, user: @current_user, badge:, revealed: false)

    patch reveal_internal_badge_path(badge.id), as: :json

    assert_response :success
    assert acquired_badge.reload.revealed?
  end

  test "PATCH reveal returns serialized badge" do
    badge = create(:member_badge)
    acquired_badge = create(:user_acquired_badge, user: @current_user, badge:, revealed: false)

    patch reveal_internal_badge_path(badge.id), as: :json

    assert_response :success
    assert_json_response({
      badge: SerializeAcquiredBadge.(acquired_badge.reload)
    })
  end

  test "PATCH reveal returns 404 when badge not found" do
    patch reveal_internal_badge_path(999), as: :json

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

    patch reveal_internal_badge_path(badge.id), as: :json

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

    patch reveal_internal_badge_path(badge.id), as: :json

    assert_response :success
  end
end
