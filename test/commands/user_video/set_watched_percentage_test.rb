require "test_helper"

class UserVideo::SetWatchedPercentageTest < ActiveSupport::TestCase
  test "creates user_video on first call" do
    user = create(:user)
    uuid = SecureRandom.uuid

    assert_difference "UserVideo.count", 1 do
      UserVideo::SetWatchedPercentage.(user, uuid, 30)
    end

    user_video = UserVideo.find_by!(user:, uuid:)
    assert_equal 30, user_video.watched_percentage
    assert_nil user_video.completed_at
  end

  test "updates existing user_video" do
    user = create(:user)
    uuid = SecureRandom.uuid
    create(:user_video, user:, uuid:, watched_percentage: 20)

    UserVideo::SetWatchedPercentage.(user, uuid, 50)

    assert_equal 50, UserVideo.find_by!(user:, uuid:).watched_percentage
  end

  test "does not go backwards" do
    user = create(:user)
    uuid = SecureRandom.uuid
    create(:user_video, user:, uuid:, watched_percentage: 75)

    UserVideo::SetWatchedPercentage.(user, uuid, 50)

    assert_equal 75, UserVideo.find_by!(user:, uuid:).watched_percentage
  end

  test "clamps over 100 to 100" do
    user = create(:user)
    uuid = SecureRandom.uuid

    UserVideo::SetWatchedPercentage.(user, uuid, 150)

    assert_equal 100, UserVideo.find_by!(user:, uuid:).watched_percentage
  end

  test "clamps negative to 0" do
    user = create(:user)
    uuid = SecureRandom.uuid

    UserVideo::SetWatchedPercentage.(user, uuid, -10)

    assert_equal 0, UserVideo.find_by!(user:, uuid:).watched_percentage
  end

  test "sets completed_at on first reach of 100" do
    user = create(:user)
    uuid = SecureRandom.uuid
    freeze_time = Time.utc(2026, 5, 8, 12)

    travel_to(freeze_time) do
      UserVideo::SetWatchedPercentage.(user, uuid, 100)
    end

    user_video = UserVideo.find_by!(user:, uuid:)
    assert_equal 100, user_video.watched_percentage
    assert_equal freeze_time, user_video.completed_at
  end

  test "does not change completed_at on subsequent 100 calls" do
    user = create(:user)
    uuid = SecureRandom.uuid
    original = Time.utc(2026, 5, 8, 12)
    create(:user_video, user:, uuid:, watched_percentage: 100, completed_at: original)

    travel_to(Time.utc(2026, 6, 1, 12)) do
      UserVideo::SetWatchedPercentage.(user, uuid, 100)
    end

    assert_equal original, UserVideo.find_by!(user:, uuid:).completed_at
  end

  test "does not set completed_at when below 100" do
    user = create(:user)
    uuid = SecureRandom.uuid

    UserVideo::SetWatchedPercentage.(user, uuid, 99)

    assert_nil UserVideo.find_by!(user:, uuid:).completed_at
  end

  test "isolates progress between users" do
    user1 = create(:user)
    user2 = create(:user)
    uuid = SecureRandom.uuid

    UserVideo::SetWatchedPercentage.(user1, uuid, 60)
    UserVideo::SetWatchedPercentage.(user2, uuid, 30)

    assert_equal 60, UserVideo.find_by!(user: user1, uuid:).watched_percentage
    assert_equal 30, UserVideo.find_by!(user: user2, uuid:).watched_percentage
  end
end
