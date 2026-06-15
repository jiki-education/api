require "test_helper"

class User::IdentifyTest < ActiveSupport::TestCase
  setup do
    Current.reset
  end

  teardown do
    Current.reset
  end

  test "calls PostHog.identify with user state snapshot" do
    user = create(:user, created_at: Date.new(2026, 1, 15), locale: "en")

    PostHog.stubs(:initialized?).returns(true)
    PostHog.expects(:identify).with(
      distinct_id: user.id.to_s,
      properties: {
        username: user.handle,
        membership_type: "standard",
        locale: "en",
        signup_date: "2026-01-15",
        "$geoip_disable": true
      }
    )

    User::Identify.(user)
  end

  test "sends $ip instead of disabling geoip when user_ip is present" do
    user = create(:user, created_at: Date.new(2026, 1, 15), locale: "en")

    PostHog.stubs(:initialized?).returns(true)
    PostHog.expects(:identify).with(
      distinct_id: user.id.to_s,
      properties: {
        username: user.handle,
        membership_type: "standard",
        locale: "en",
        signup_date: "2026-01-15",
        "$ip": "86.41.10.20"
      }
    )

    User::Identify.(user, user_ip: "86.41.10.20")
  end

  test "defer materialises Current.user_ip into the job" do
    user = create(:user, created_at: Date.new(2026, 1, 15), locale: "en")
    Current.user_ip = "86.41.10.20"

    PostHog.stubs(:initialized?).returns(true)
    PostHog.expects(:identify).with(
      distinct_id: user.id.to_s,
      properties: {
        username: user.handle,
        membership_type: "standard",
        locale: "en",
        signup_date: "2026-01-15",
        "$ip": "86.41.10.20"
      }
    )

    perform_enqueued_jobs do
      User::Identify.defer(user)
    end
  end

  test "defer disables geoip when Current.user_ip is not set" do
    user = create(:user, created_at: Date.new(2026, 1, 15), locale: "en")

    PostHog.stubs(:initialized?).returns(true)
    PostHog.expects(:identify).with(
      distinct_id: user.id.to_s,
      properties: {
        username: user.handle,
        membership_type: "standard",
        locale: "en",
        signup_date: "2026-01-15",
        "$geoip_disable": true
      }
    )

    perform_enqueued_jobs do
      User::Identify.defer(user)
    end
  end

  test "defer does not override an explicitly passed user_ip" do
    user = create(:user, created_at: Date.new(2026, 1, 15), locale: "en")
    Current.user_ip = "9.9.9.9"

    PostHog.stubs(:initialized?).returns(true)
    PostHog.expects(:identify).with(
      distinct_id: user.id.to_s,
      properties: {
        username: user.handle,
        membership_type: "standard",
        locale: "en",
        signup_date: "2026-01-15",
        "$ip": "86.41.10.20"
      }
    )

    perform_enqueued_jobs do
      User::Identify.defer(user, user_ip: "86.41.10.20")
    end
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
