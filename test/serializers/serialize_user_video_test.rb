require "test_helper"

class SerializeUserVideoTest < ActiveSupport::TestCase
  test "serializes started user_video" do
    user_video = create(:user_video, slug: "building-basics-01", watched_percentage: 42, completed_at: nil)

    expected = {
      slug: "building-basics-01",
      watched_percentage: 42,
      status: "started",
      completed_at: nil
    }

    assert_equal(expected, SerializeUserVideo.(user_video))
  end

  test "serializes completed user_video" do
    completed_at = Time.utc(2026, 5, 8, 12)
    user_video = create(:user_video,
      slug: "building-basics-01",
      watched_percentage: 100,
      completed_at:)

    expected = {
      slug: "building-basics-01",
      watched_percentage: 100,
      status: "completed",
      completed_at: completed_at.iso8601
    }

    assert_equal(expected, SerializeUserVideo.(user_video))
  end
end
