require "test_helper"

class UserVideoTest < ActiveSupport::TestCase
  test "valid factory" do
    assert build(:user_video).valid?
  end

  test "requires slug" do
    user_video = build(:user_video, slug: nil)
    refute user_video.valid?
  end

  test "unique user and slug combination" do
    user = create(:user)
    create(:user_video, user:, slug: "building-basics-01")
    duplicate = build(:user_video, user:, slug: "building-basics-01")

    refute duplicate.valid?
  end

  test "same slug allowed for different users" do
    create(:user_video, user: create(:user), slug: "building-basics-01")
    other = build(:user_video, user: create(:user), slug: "building-basics-01")

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
