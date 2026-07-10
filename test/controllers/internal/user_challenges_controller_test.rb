require "test_helper"

class Internal::UserChallengesControllerTest < ApplicationControllerTest
  setup do
    setup_user
    make_premium(@current_user)
    @challenge = create(:challenge)
  end

  # Authentication guards
  guard_incorrect_token! :internal_user_challenge_path, args: ["calculator"], method: :get
  guard_incorrect_token! :start_internal_user_challenge_path, args: ["calculator"], method: :post
  guard_incorrect_token! :complete_internal_user_challenge_path, args: ["calculator"], method: :patch

  # GET /v1/user_challenges/:slug tests
  test "GET show returns user challenge progress" do
    user_challenge = create(:user_challenge, user: @current_user, challenge: @challenge)
    serialized_data = { challenge_slug: @challenge.slug, status: "started", conversation: [], data: {} }

    SerializeUserChallenge.expects(:call).with(user_challenge).returns(serialized_data)

    get internal_user_challenge_path(challenge_slug: @challenge.slug),
      as: :json

    assert_response :success
    assert_json_response({ user_challenge: serialized_data })
  end

  test "GET show returns 404 when user_challenge does not exist" do
    get internal_user_challenge_path(challenge_slug: @challenge.slug),
      as: :json

    assert_json_error(:not_found, error_type: :user_challenge_not_found)
  end

  test "GET show returns 404 for non-existent challenge" do
    get internal_user_challenge_path(challenge_slug: "non-existent-slug"),
      as: :json

    assert_json_error(:not_found, error_type: :challenge_not_found)
  end

  test "GET show returns 403 for non-premium user" do
    make_non_premium(@current_user)

    get internal_user_challenge_path(challenge_slug: @challenge.slug),
      as: :json

    assert_json_error(:forbidden, error_type: :premium_required)
  end

  # POST /v1/user_challenges/:slug/start tests
  test "POST start creates and starts the user challenge" do
    freeze_time do
      post start_internal_user_challenge_path(challenge_slug: @challenge.slug),
        as: :json

      assert_response :success
      assert_json_response({})

      user_challenge = UserChallenge.find_by!(user: @current_user, challenge: @challenge)
      assert_equal Time.current, user_challenge.started_at
    end
  end

  test "POST start delegates to UserChallenge::Start command" do
    UserChallenge::Start.expects(:call).with(@current_user, @challenge)

    post start_internal_user_challenge_path(challenge_slug: @challenge.slug),
      as: :json

    assert_response :success
  end

  test "POST start is idempotent" do
    post start_internal_user_challenge_path(challenge_slug: @challenge.slug), as: :json
    original_started_at = UserChallenge.find_by!(user: @current_user, challenge: @challenge).started_at

    travel 1.hour do
      post start_internal_user_challenge_path(challenge_slug: @challenge.slug), as: :json
      assert_response :success
    end

    assert_equal original_started_at,
      UserChallenge.find_by!(user: @current_user, challenge: @challenge).started_at
  end

  test "POST start returns 404 for non-existent challenge" do
    post start_internal_user_challenge_path(challenge_slug: "non-existent-slug"),
      as: :json

    assert_json_error(:not_found, error_type: :challenge_not_found)
  end

  test "POST start returns 403 for non-premium user" do
    make_non_premium(@current_user)

    post start_internal_user_challenge_path(challenge_slug: @challenge.slug),
      as: :json

    assert_json_error(:forbidden, error_type: :premium_required)
  end

  test "POST start returns 403 when challenge is locked" do
    lesson = create(:lesson, :exercise)
    @challenge.update!(unlocked_by_lesson: lesson)

    post start_internal_user_challenge_path(challenge_slug: @challenge.slug),
      as: :json

    assert_json_error(:forbidden, error_type: :challenge_locked)
    assert_equal 0, UserChallenge.count
  end

  # PATCH /v1/user_challenges/:slug/complete tests
  test "PATCH complete successfully completes a challenge" do
    create(:user_challenge, user: @current_user, challenge: @challenge)

    patch complete_internal_user_challenge_path(challenge_slug: @challenge.slug),
      as: :json

    assert_response :success
    assert_json_response({})
  end

  test "PATCH complete delegates to UserChallenge::Complete command" do
    user_challenge = create(:user_challenge, user: @current_user, challenge: @challenge)
    UserChallenge::Complete.expects(:call).with(user_challenge)

    patch complete_internal_user_challenge_path(challenge_slug: @challenge.slug),
      as: :json

    assert_response :success
  end

  test "PATCH complete returns 404 for non-existent challenge" do
    patch complete_internal_user_challenge_path(challenge_slug: "non-existent-slug"),
      as: :json

    assert_json_error(:not_found, error_type: :challenge_not_found)
  end

  test "PATCH complete returns 404 when challenge not started" do
    patch complete_internal_user_challenge_path(challenge_slug: @challenge.slug),
      as: :json

    assert_json_error(:not_found, error_type: :user_challenge_not_found)
  end

  test "PATCH complete returns 403 for non-premium user" do
    make_non_premium(@current_user)

    patch complete_internal_user_challenge_path(challenge_slug: @challenge.slug),
      as: :json

    assert_json_error(:forbidden, error_type: :premium_required)
  end

  test "PATCH complete is idempotent" do
    user_challenge = create(:user_challenge, user: @current_user, challenge: @challenge)

    freeze_time do
      patch complete_internal_user_challenge_path(challenge_slug: @challenge.slug),
        as: :json

      assert_response :success
      assert_equal Time.current, user_challenge.reload.completed_at
    end

    original_completed_at = user_challenge.completed_at

    travel 1.hour do
      patch complete_internal_user_challenge_path(challenge_slug: @challenge.slug),
        as: :json

      assert_response :success
    end

    assert_equal original_completed_at, user_challenge.reload.completed_at
  end
end
