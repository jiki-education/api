require "test_helper"

class Analytics::TrackEventTest < ActiveSupport::TestCase
  setup do
    Current.reset
  end

  teardown do
    Current.reset
  end

  test "captures event with default properties merged in" do
    user = create(:user, locale: "en")

    PostHog.stubs(:initialized?).returns(true)
    PostHog.expects(:capture).with(
      distinct_id: user.id.to_s,
      event: "premium_modal_shown",
      properties: {
        trigger: "upgrade_cta_nav",
        membership_type: "standard",
        locale: "en",
        "$geoip_disable": true
      }
    )

    Analytics::TrackEvent.(user, "premium_modal_shown", properties: { trigger: "upgrade_cta_nav" })
  end

  test "works with no properties" do
    user = create(:user)

    PostHog.stubs(:initialized?).returns(true)
    PostHog.expects(:capture).with(
      distinct_id: user.id.to_s,
      event: "user_signed_up",
      properties: {
        membership_type: user.membership_type,
        locale: user.locale,
        "$geoip_disable": true
      }
    )

    Analytics::TrackEvent.(user, "user_signed_up")
  end

  test "sends $ip instead of disabling geoip when user_ip is present" do
    user = create(:user, locale: "en")

    PostHog.stubs(:initialized?).returns(true)
    PostHog.expects(:capture).with(
      distinct_id: user.id.to_s,
      event: "user_signed_up",
      properties: {
        membership_type: "standard",
        locale: "en",
        "$ip": "86.41.10.20"
      }
    )

    Analytics::TrackEvent.(user, "user_signed_up", user_ip: "86.41.10.20")
  end

  test "defer materialises Current.user_ip into the job" do
    user = create(:user, locale: "en")
    Current.user_ip = "86.41.10.20"

    PostHog.stubs(:initialized?).returns(true)
    PostHog.expects(:capture).with(
      distinct_id: user.id.to_s,
      event: "user_signed_up",
      properties: {
        membership_type: "standard",
        locale: "en",
        "$ip": "86.41.10.20"
      }
    )

    perform_enqueued_jobs do
      Analytics::TrackEvent.defer(user, "user_signed_up")
    end
  end

  test "defer disables geoip when Current.user_ip is not set" do
    user = create(:user, locale: "en")

    PostHog.stubs(:initialized?).returns(true)
    PostHog.expects(:capture).with(
      distinct_id: user.id.to_s,
      event: "user_signed_up",
      properties: {
        membership_type: "standard",
        locale: "en",
        "$geoip_disable": true
      }
    )

    perform_enqueued_jobs do
      Analytics::TrackEvent.defer(user, "user_signed_up")
    end
  end

  test "defer does not override an explicitly passed user_ip" do
    user = create(:user, locale: "en")
    Current.user_ip = "9.9.9.9"

    PostHog.stubs(:initialized?).returns(true)
    PostHog.expects(:capture).with(
      distinct_id: user.id.to_s,
      event: "user_signed_up",
      properties: {
        membership_type: "standard",
        locale: "en",
        "$ip": "86.41.10.20"
      }
    )

    perform_enqueued_jobs do
      Analytics::TrackEvent.defer(user, "user_signed_up", user_ip: "86.41.10.20")
    end
  end

  test "no-ops when PostHog is not initialized" do
    PostHog.stubs(:initialized?).returns(false)
    PostHog.expects(:capture).never

    Analytics::TrackEvent.(create(:user), "user_signed_up")
  end

  test "uses :analytics queue" do
    assert_equal :analytics, Analytics::TrackEvent.active_job_queue
  end
end
