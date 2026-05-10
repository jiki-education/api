require "test_helper"

class Internal::UserVideosControllerTest < ApplicationControllerTest
  setup { setup_user }

  guard_incorrect_token! :internal_user_videos_path, method: :get
  guard_incorrect_token! :internal_user_video_path, args: ["11111111-1111-1111-1111-111111111111"], method: :get
  guard_incorrect_token! :internal_user_video_path, args: ["11111111-1111-1111-1111-111111111111"], method: :patch

  # GET /v1/user_videos
  test "GET index returns user's videos" do
    uuid1 = "11111111-1111-1111-1111-111111111111"
    uuid2 = "22222222-2222-2222-2222-222222222222"
    v1 = create(:user_video, user: @current_user, uuid: uuid2, watched_percentage: 50)
    v2 = create(:user_video, user: @current_user, uuid: uuid1, watched_percentage: 100, completed_at: Time.current)
    create(:user_video, user: create(:user), uuid: uuid1, watched_percentage: 10) # other user

    get internal_user_videos_path, as: :json

    assert_response :success
    assert_json_response({
      user_videos: [
        SerializeUserVideo.(v1),
        SerializeUserVideo.(v2)
      ]
    })
  end

  test "GET index returns empty when user has no videos" do
    get internal_user_videos_path, as: :json

    assert_response :success
    assert_json_response({ user_videos: [] })
  end

  # GET /v1/user_videos/:uuid
  test "GET show returns the user's video" do
    uuid = SecureRandom.uuid
    user_video = create(:user_video, user: @current_user, uuid:, watched_percentage: 50)
    create(:user_video, user: create(:user), uuid:, watched_percentage: 10)

    get internal_user_video_path(uuid:), as: :json

    assert_response :success
    assert_json_response({ user_video: SerializeUserVideo.(user_video) })
  end

  test "GET show returns 404 when user has no video for uuid" do
    uuid = SecureRandom.uuid
    create(:user_video, user: create(:user), uuid:, watched_percentage: 10)

    get internal_user_video_path(uuid:), as: :json

    assert_response :not_found
    assert_json_response({
      error: { type: "user_video_not_found", message: "User video not found" }
    })
  end

  # PATCH /v1/user_videos/:uuid
  test "PATCH update delegates to command and returns serialized payload" do
    uuid = "11111111-1111-1111-1111-111111111111"
    UserVideo::SetWatchedPercentage.expects(:call).with(@current_user, uuid, 40).returns(
      build_stubbed(:user_video, uuid:, watched_percentage: 40)
    )

    patch internal_user_video_path(uuid:),
      params: { watched_percentage: 40 },
      as: :json

    assert_response :success
    response_body = JSON.parse(response.body, symbolize_names: true)
    assert_equal uuid, response_body[:user_video][:uuid]
    assert_equal 40, response_body[:user_video][:watched_percentage]
  end

  test "PATCH update creates user_video when not present" do
    uuid = SecureRandom.uuid
    assert_difference "UserVideo.count", 1 do
      patch internal_user_video_path(uuid:),
        params: { watched_percentage: 30 },
        as: :json
    end

    assert_response :success
    user_video = UserVideo.find_by!(user: @current_user, uuid:)
    assert_equal 30, user_video.watched_percentage
  end

  test "PATCH update ratchets watched_percentage" do
    uuid = SecureRandom.uuid
    create(:user_video, user: @current_user, uuid:, watched_percentage: 80)

    patch internal_user_video_path(uuid:),
      params: { watched_percentage: 50 },
      as: :json

    assert_response :success
    response_body = JSON.parse(response.body, symbolize_names: true)
    assert_equal 80, response_body[:user_video][:watched_percentage]
  end

  test "PATCH update sets completed status when reaching 100" do
    uuid = SecureRandom.uuid
    patch internal_user_video_path(uuid:),
      params: { watched_percentage: 100 },
      as: :json

    assert_response :success
    response_body = JSON.parse(response.body, symbolize_names: true)
    assert_equal "completed", response_body[:user_video][:status]
    refute_nil response_body[:user_video][:completed_at]
  end
end
