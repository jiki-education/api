require "test_helper"

class Internal::ChallengesControllerTest < ApplicationControllerTest
  setup do
    setup_user
    make_premium(@current_user)
  end

  # Authentication guards
  guard_incorrect_token! :internal_challenges_path, method: :get
  guard_incorrect_token! :internal_challenge_path, method: :get, args: ["test-challenge"]

  # GET /v1/challenges (index) tests
  test "GET index returns challenges with unlocked first, then locked" do
    Prosopite.finish
    challenge_zebra = create(:challenge, title: "Zebra Challenge")
    challenge_apple = create(:challenge, title: "Apple Challenge")
    challenge_middle = create(:challenge, title: "Middle Challenge")

    # Unlock Zebra and Middle for current user
    create(:user_challenge, user: @current_user, challenge: challenge_zebra)
    create(:user_challenge, user: @current_user, challenge: challenge_middle)

    get internal_challenges_path, as: :json

    assert_response :success
    # Unlocked first (Middle, Zebra), then locked (Apple)
    assert_json_response({
      results: SerializeChallenges.([challenge_middle, challenge_zebra, challenge_apple], for_user: @current_user),
      meta: {
        current_page: 1,
        total_pages: 1,
        total_count: 3,
        events: []
      }
    })
  end

  test "GET index returns all challenges when user has none unlocked" do
    Prosopite.finish
    challenge_apple = create(:challenge, title: "Apple Challenge")
    challenge_banana = create(:challenge, title: "Banana Challenge")

    get internal_challenges_path, as: :json

    assert_response :success
    # All locked, ordered by title
    assert_json_response({
      results: SerializeChallenges.([challenge_apple, challenge_banana], for_user: @current_user),
      meta: {
        current_page: 1,
        total_pages: 1,
        total_count: 2,
        events: []
      }
    })
  end

  test "GET index shows started status" do
    Prosopite.finish
    challenge = create(:challenge, title: "Calculator")
    create(:user_challenge, user: @current_user, challenge:, started_at: Time.current, completed_at: nil)

    get internal_challenges_path, as: :json

    assert_response :success
    assert_json_response({
      results: SerializeChallenges.([challenge], for_user: @current_user),
      meta: {
        current_page: 1,
        total_pages: 1,
        total_count: 1,
        events: []
      }
    })
  end

  test "GET index shows completed status" do
    Prosopite.finish
    challenge = create(:challenge, title: "Calculator")
    create(:user_challenge, user: @current_user, challenge:, started_at: 2.days.ago, completed_at: Time.current)

    get internal_challenges_path, as: :json

    assert_response :success
    assert_json_response({
      results: SerializeChallenges.([challenge], for_user: @current_user),
      meta: {
        current_page: 1,
        total_pages: 1,
        total_count: 1,
        events: []
      }
    })
  end

  test "GET index filters by title parameter" do
    Prosopite.finish
    challenge_calc_app = create(:challenge, title: "Calculator App")
    create(:challenge, title: "Todo List")
    challenge_sci_calc = create(:challenge, title: "Scientific Calculator")

    create(:user_challenge, user: @current_user, challenge: challenge_sci_calc)

    get internal_challenges_path(title: "Calculator"), as: :json

    assert_response :success
    # Scientific Calculator (unlocked) first, then Calculator App (locked)
    assert_json_response({
      results: SerializeChallenges.([challenge_sci_calc, challenge_calc_app], for_user: @current_user),
      meta: {
        current_page: 1,
        total_pages: 1,
        total_count: 2,
        events: []
      }
    })
  end

  test "GET index supports pagination with page parameter" do
    Prosopite.finish
    challenge_apple = create(:challenge, title: "Apple")
    create(:challenge, title: "Banana")
    challenge_cherry = create(:challenge, title: "Cherry")

    create(:user_challenge, user: @current_user, challenge: challenge_cherry)

    get internal_challenges_path(page: 1, per: 2), as: :json

    assert_response :success
    assert_json_response({
      results: SerializeChallenges.([challenge_cherry, challenge_apple], for_user: @current_user),
      meta: {
        current_page: 1,
        total_pages: 2,
        total_count: 3,
        events: []
      }
    })
  end

  test "GET index supports pagination with per parameter" do
    Prosopite.finish
    challenges = Array.new(5) { |i| create(:challenge, title: "Challenge #{i}") }

    get internal_challenges_path(per: 3), as: :json

    assert_response :success
    assert_json_response({
      results: SerializeChallenges.(challenges.first(3), for_user: @current_user),
      meta: {
        current_page: 1,
        total_pages: 2,
        total_count: 5,
        events: []
      }
    })
  end

  test "GET index returns correct fields" do
    Prosopite.finish
    challenge = create(:challenge, slug: "calculator", title: "Calculator", description: "Build a calculator")

    get internal_challenges_path, as: :json

    assert_response :success
    assert_json_response({
      results: SerializeChallenges.([challenge], for_user: @current_user),
      meta: {
        current_page: 1,
        total_pages: 1,
        total_count: 1,
        events: []
      }
    })
  end

  test "GET index is accessible to non-premium users" do
    Prosopite.finish
    make_non_premium(@current_user)
    challenge = create(:challenge, title: "Calculator")

    get internal_challenges_path, as: :json

    assert_response :success
    assert_json_response({
      results: SerializeChallenges.([challenge], for_user: @current_user),
      meta: {
        current_page: 1,
        total_pages: 1,
        total_count: 1,
        events: []
      }
    })
  end

  # GET /v1/challenges/:slug (show) tests
  test "GET show returns challenge by slug" do
    Prosopite.finish
    challenge = create(:challenge, slug: "calculator", title: "Calculator", description: "Build a calculator")

    get internal_challenge_path(challenge_slug: challenge.slug), as: :json

    assert_response :success
    assert_json_response({
      challenge: SerializeChallenge.(challenge)
    })
  end

  test "GET show returns 404 for non-existent challenge" do
    Prosopite.finish

    get internal_challenge_path(challenge_slug: "non-existent"), as: :json

    assert_json_error(:not_found, error_type: :challenge_not_found)
  end

  test "GET show returns 403 for non-premium user" do
    Prosopite.finish
    make_non_premium(@current_user)
    challenge = create(:challenge, slug: "calculator")

    get internal_challenge_path(challenge_slug: challenge.slug), as: :json

    assert_json_error(:forbidden, error_type: :premium_required)
  end
end
