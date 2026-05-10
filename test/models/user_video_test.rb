require "test_helper"

class UserVideoTest < ActiveSupport::TestCase
  test "valid factory" do
    assert build(:user_video).valid?
  end

  test "requires uuid" do
    user_video = build(:user_video, uuid: nil)
    refute user_video.valid?
  end

  test "unique user and uuid combination" do
    user = create(:user)
    uuid = SecureRandom.uuid
    create(:user_video, user:, uuid:)
    duplicate = build(:user_video, user:, uuid:)

    refute duplicate.valid?
  end

  test "same uuid allowed for different users" do
    uuid = SecureRandom.uuid
    create(:user_video, user: create(:user), uuid:)
    other = build(:user_video, user: create(:user), uuid:)

    assert other.valid?
  end

  test "watched_percentage must be 0..100" do
    refute build(:user_video, watched_percentage: -1).valid?
    refute build(:user_video, watched_percentage: 101).valid?
    assert build(:user_video, watched_percentage: 0).valid?
    assert build(:user_video, watched_percentage: 100).valid?
  end

  test "completed scope returns only videos with completed_at" do
    completed = create(:user_video, completed_at: Time.current)
    create(:user_video, completed_at: nil)

    assert_equal [completed], UserVideo.completed.to_a
  end
end
