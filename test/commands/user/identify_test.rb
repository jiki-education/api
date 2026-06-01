require "test_helper"

class User::IdentifyTest < ActiveSupport::TestCase
  test "calls PostHog.identify with user state snapshot" do
    user = create(:user, created_at: Date.new(2026, 1, 15), locale: "en")

    PostHog.stubs(:initialized?).returns(true)
    PostHog.expects(:identify).with(
      distinct_id: user.id.to_s,
      properties: {
        membership_type: "standard",
        locale: "en",
        signup_date: "2026-01-15"
      }
    )

    User::Identify.(user)
  end

  test "no-ops when PostHog is not initialized" do
    PostHog.stubs(:initialized?).returns(false)
    PostHog.expects(:identify).never

    User::Identify.(create(:user))
  end

  test "uses :analytics queue" do
    assert_equal :analytics, User::Identify.active_job_queue
  end
end
