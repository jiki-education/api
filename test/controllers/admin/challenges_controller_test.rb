require "test_helper"

class Admin::ChallengesControllerTest < ApplicationControllerTest
  setup do
    @admin = create(:user, :admin)
    sign_in_user(@admin)
  end

  # Authentication and authorization guards
  guard_admin! :admin_challenges_path, method: :get
  guard_admin! :admin_challenges_path, method: :post
  guard_admin! :admin_challenge_path, args: [1], method: :get
  guard_admin! :admin_challenge_path, args: [1], method: :patch
  guard_admin! :admin_challenge_path, args: [1], method: :delete

  # INDEX tests

  test "GET index returns all challenges with pagination" do
    Prosopite.finish # Stop scan before creating test data
    challenge1 = create(:challenge, title: "Calculator", slug: "calculator")
    challenge2 = create(:challenge, title: "Todo App", slug: "todo-app")

    Prosopite.scan # Resume scan for the actual request
    get admin_challenges_path, as: :json

    assert_response :success
    assert_json_response({
      results: SerializeAdminChallenges.([challenge1, challenge2]),
      meta: {
        current_page: 1,
        total_pages: 1,
        total_count: 2
      }
    })
  end

  test "GET index filters by title" do
    Prosopite.finish
    challenge1 = create(:challenge)
    challenge1.update!(title: "Calculator App")
    challenge2 = create(:challenge)
    challenge2.update!(title: "Todo List")

    Prosopite.scan
    get admin_challenges_path(title: "Calculator"), as: :json

    assert_response :success
    assert_json_response({
      results: SerializeAdminChallenges.([challenge1]),
      meta: {
        current_page: 1,
        total_pages: 1,
        total_count: 1
      }
    })
  end

  test "GET index supports pagination" do
    Prosopite.finish
    challenge1 = create(:challenge, title: "AAA Challenge")
    challenge2 = create(:challenge, title: "BBB Challenge")
    create(:challenge, title: "CCC Challenge")

    Prosopite.scan
    get admin_challenges_path(page: 1, per: 2), as: :json

    assert_response :success
    assert_json_response({
      results: SerializeAdminChallenges.([challenge1, challenge2]),
      meta: {
        current_page: 1,
        total_pages: 2,
        total_count: 3
      }
    })
  end

  test "GET index returns empty results when no challenges exist" do
    get admin_challenges_path, as: :json

    assert_response :success
    assert_json_response({
      results: [],
      meta: {
        current_page: 1,
        total_pages: 0,
        total_count: 0
      }
    })
  end

  test "GET index does not use user filtering" do
    Prosopite.finish
    challenge_1 = create(:challenge, title: "Apple Challenge")
    challenge_2 = create(:challenge, title: "Zebra Challenge")

    # Create a regular user and unlock a challenge
    regular_user = create(:user)
    create(:user_challenge, user: regular_user, challenge: challenge_2)

    Prosopite.scan
    get admin_challenges_path, as: :json

    assert_response :success
    # Admin should see all challenges ordered by title (default ordering)
    assert_json_response({
      results: SerializeAdminChallenges.([challenge_1, challenge_2]),
      meta: {
        current_page: 1,
        total_pages: 1,
        total_count: 2
      }
    })
  end

  # CREATE tests

  test "POST create creates challenge with valid attributes" do
    challenge_params = {
      challenge: {
        title: "Calculator",
        slug: "calculator",
        description: "Build a calculator application",
        exercise_slug: "calculator-challenge"
      }
    }

    assert_difference "Challenge.count", 1 do
      post admin_challenges_path, params: challenge_params, as: :json
    end

    assert_response :created

    challenge = Challenge.last
    assert_json_response({
      challenge: SerializeAdminChallenge.(challenge)
    })
  end

  test "POST create returns validation error for invalid attributes" do
    challenge_params = {
      challenge: {
        title: ""
      }
    }

    assert_no_difference "Challenge.count" do
      post admin_challenges_path, params: challenge_params, as: :json
    end

    assert_response :unprocessable_entity
    json = response.parsed_body
    assert_equal "validation_error", json["error"]["type"]
    assert_includes json["error"]["errors"]["title"], "can't be blank"
  end

  # SHOW tests

  test "GET show returns challenge" do
    challenge = create(:challenge, title: "Calculator", exercise_slug: "calculator-challenge")

    get admin_challenge_path(challenge.id), as: :json

    assert_response :success
    assert_json_response({
      challenge: SerializeAdminChallenge.(challenge)
    })
  end

  test "GET show returns 404 for non-existent challenge" do
    get admin_challenge_path(999_999), as: :json

    assert_json_error(:not_found, error_type: :challenge_not_found)
  end

  # UPDATE tests

  test "PATCH update updates challenge with valid attributes" do
    challenge = create(:challenge, title: "Original")
    update_params = {
      challenge: {
        title: "Updated"
      }
    }

    patch admin_challenge_path(challenge.id), params: update_params, as: :json

    assert_response :success

    challenge.reload
    assert_json_response({
      challenge: SerializeAdminChallenge.(challenge)
    })
  end

  test "PATCH update returns validation error for invalid attributes" do
    challenge = create(:challenge)
    update_params = {
      challenge: {
        title: ""
      }
    }

    patch admin_challenge_path(challenge.id), params: update_params, as: :json

    assert_response :unprocessable_entity
    json = response.parsed_body
    assert_equal "validation_error", json["error"]["type"]
    assert_includes json["error"]["errors"]["title"], "can't be blank"
  end

  test "PATCH update returns 404 for non-existent challenge" do
    update_params = {
      challenge: {
        title: "Updated"
      }
    }

    patch admin_challenge_path(999_999), params: update_params, as: :json

    assert_json_error(:not_found, error_type: :challenge_not_found)
  end

  # DESTROY tests

  test "DELETE destroy deletes challenge" do
    challenge = create(:challenge)

    assert_difference "Challenge.count", -1 do
      delete admin_challenge_path(challenge.id), as: :json
    end

    assert_response :no_content
  end

  test "DELETE destroy returns 404 for non-existent challenge" do
    delete admin_challenge_path(999_999), as: :json

    assert_json_error(:not_found, error_type: :challenge_not_found)
  end
end
