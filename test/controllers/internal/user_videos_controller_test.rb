require "test_helper"

class Internal::UserVideosControllerTest < ApplicationControllerTest
  setup { setup_user }

  guard_incorrect_token! :internal_user_videos_path, method: :get
  guard_incorrect_token! :internal_user_video_path, args: ["building-basics-01"], method: :get
  guard_incorrect_token! :internal_user_video_path, args: ["building-basics-01"], method: :patch

  # GET /v1/user_videos
  test "GET index returns user's videos" do
    v1 = create(:user_video, user: @current_user, slug: "intro", watched_percentage: 50)
    v2 = create(:user_video, user: @current_user, slug: "auth", watched_percentage: 100, completed_at: Time.current)
    create(:user_video, user: create(:user), slug: "intro", watched_percentage: 10) # other user

    get internal_user_videos_path, as: :json

    assert_response :success
    assert_json_response({
      user_videos: [
        SerializeUserVideo.(v2),
        SerializeUserVideo.(v1)
      ]
    })
  end

  test "GET index returns empty when user has no videos" do
    get internal_user_videos_path, as: :json

    assert_response :success
    assert_json_response({ user_videos: [] })
  end

  # GET /v1/user_videos/:slug
  test "GET show returns the user's video" do
    user_video = create(:user_video, user: @current_user, slug: "intro", watched_percentage: 50)
    create(:user_video, user: create(:user), slug: "intro", watched_percentage: 10)

    get internal_user_video_path(slug: "intro"), as: :json

    assert_response :success
    assert_json_response({ user_video: SerializeUserVideo.(user_video) })
  end

  test "GET show returns 404 when user has no video for slug" do
    create(:user_video, user: create(:user), slug: "intro", watched_percentage: 10)

    get internal_user_video_path(slug: "intro"), as: :json

    assert_response :not_found
    assert_json_response({
      error: { type: "user_video_not_found", message: "User video not found" }
    })
  end

  # PATCH /v1/user_videos/:slug
  test "PATCH update delegates to command and returns serialized payload" do
    UserVideo::SetWatchedPercentage.expects(:call).with(@current_user, "building-basics-01", 40).returns(
      build_stubbed(:user_video, slug: "building-basics-01", watched_percentage: 40)
    )

    patch internal_user_video_path(slug: "building-basics-01"),
      params: { watched_percentage: 40 },
      as: :json

    assert_response :success
    response_body = JSON.parse(response.body, symbolize_names: true)
    assert_equal "building-basics-01", response_body[:user_video][:slug]
    assert_equal 40, response_body[:user_video][:watched_percentage]
  end

  test "PATCH update creates user_video when not present" do
    assert_difference "UserVideo.count", 1 do
      patch internal_user_video_path(slug: "building-basics-01"),
        params: { watched_percentage: 30 },
        as: :json
    end

    assert_response :success
    user_video = UserVideo.find_by!(user: @current_user, slug: "building-basics-01")
    assert_equal 30, user_video.watched_percentage
  end

  test "PATCH update ratchets watched_percentage" do
    create(:user_video, user: @current_user, slug: "intro", watched_percentage: 80)

    patch internal_user_video_path(slug: "intro"),
      params: { watched_percentage: 50 },
      as: :json

    assert_response :success
    response_body = JSON.parse(response.body, symbolize_names: true)
    assert_equal 80, response_body[:user_video][:watched_percentage]
  end

  test "PATCH update sets completed status when reaching 100" do
    patch internal_user_video_path(slug: "intro"),
      params: { watched_percentage: 100 },
      as: :json

    assert_response :success
    response_body = JSON.parse(response.body, symbolize_names: true)
    assert_equal "completed", response_body[:user_video][:status]
    refute_nil response_body[:user_video][:completed_at]
  end
end
