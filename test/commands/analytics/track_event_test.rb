require "test_helper"

class Analytics::TrackEventTest < ActiveSupport::TestCase
  test "captures event with default properties merged in" do
    user = create(:user, locale: "en")

    PostHog.expects(:capture).with(
      distinct_id: user.id.to_s,
      event: "premium_modal_shown",
      properties: {
        trigger: "upgrade_cta_nav",
        membership_type: "standard",
        locale: "en"
      }
    )

    Analytics::TrackEvent.(user, "premium_modal_shown", properties: { trigger: "upgrade_cta_nav" })
  end

  test "works with no properties" do
    user = create(:user)

    PostHog.expects(:capture).with(
      distinct_id: user.id.to_s,
      event: "user_signed_up",
      properties: {
        membership_type: user.membership_type,
        locale: user.locale
      }
    )

    Analytics::TrackEvent.(user, "user_signed_up")
  end

  test "uses :analytics queue" do
    assert_equal :analytics, Analytics::TrackEvent.active_job_queue
  end
end
