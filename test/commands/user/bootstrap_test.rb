require "test_helper"

class User::BootstrapTest < ActiveSupport::TestCase
  test "enqueues welcome email" do
    create(:course, slug: "coding-fundamentals")
    user = create(:user)

    assert_enqueued_with(
      job: ActionMailer::MailDeliveryJob,
      args: ["AccountMailer", "welcome", "deliver_now", { args: [user] }]
    ) do
      User::Bootstrap.(user, "email")
    end
  end

  test "enrolls user in coding-fundamentals course" do
    course = create(:course, slug: "coding-fundamentals")
    user = create(:user)

    User::Bootstrap.(user, "email")

    assert UserCourse.exists?(user:, course:)
  end

  test "enqueues member badge award job" do
    create(:course, slug: "coding-fundamentals")
    user = create(:user)

    assert_enqueued_with(job: AwardBadgeJob, args: [user, 'member']) do
      User::Bootstrap.(user, "email")
    end
  end

  test "awards member badge to new user" do
    create(:course, slug: "coding-fundamentals")
    user = create(:user)

    perform_enqueued_jobs do
      User::Bootstrap.(user, "email")
    end

    assert user.acquired_badges.joins(:badge).where(badges: { type: 'Badges::MemberBadge' }).exists?
  end

  test "defers Identify and user_signed_up event with provider" do
    create(:course, slug: "coding-fundamentals")
    user = create(:user)

    User::Identify.expects(:defer).with(user)
    Analytics::TrackEvent.expects(:defer).with(
      user,
      "user_signed_up",
      properties: { provider: "email" }
    )

    User::Bootstrap.(user, "email")
  end

  test "merges attribution into event properties and persists to user.data" do
    create(:course, slug: "coding-fundamentals")
    user = create(:user)
    attribution = {
      "utm_source" => "twitter",
      "utm_medium" => "social",
      "utm_campaign" => "launch",
      "referrer" => "https://t.co/foo",
      "landing_path" => "/blog/welcome"
    }

    User::Identify.expects(:defer).with(user)
    Analytics::TrackEvent.expects(:defer).with(
      user,
      "user_signed_up",
      properties: {
        provider: "google",
        "utm_source" => "twitter",
        "utm_medium" => "social",
        "utm_campaign" => "launch",
        "referrer" => "https://t.co/foo",
        "landing_path" => "/blog/welcome",
        "$referrer": "https://t.co/foo",
        "$referring_domain": "t.co",
        "$current_url": "#{Jiki.config.frontend_base_url}/blog/welcome",
        "$set_once": {
          "$initial_referrer": "https://t.co/foo",
          "$initial_referring_domain": "t.co",
          "$initial_current_url": "#{Jiki.config.frontend_base_url}/blog/welcome",
          "$initial_utm_source": "twitter",
          "$initial_utm_medium": "social",
          "$initial_utm_campaign": "launch"
        }
      }
    )

    User::Bootstrap.(user, "google", attribution: attribution)

    assert_equal attribution, user.data.reload.signup_attribution
  end

  test "uses $direct as referrer when attribution has no referrer" do
    create(:course, slug: "coding-fundamentals")
    user = create(:user)
    attribution = { "utm_source" => "newsletter" }

    User::Identify.stubs(:defer)
    Analytics::TrackEvent.expects(:defer).with(
      user,
      "user_signed_up",
      properties: {
        provider: "email",
        "utm_source" => "newsletter",
        "$referrer": "$direct",
        "$referring_domain": "$direct",
        "$set_once": {
          "$initial_referrer": "$direct",
          "$initial_referring_domain": "$direct",
          "$initial_utm_source": "newsletter"
        }
      }
    )

    User::Bootstrap.(user, "email", attribution: attribution)
  end

  test "uses $direct as referring domain when referrer is not a valid URL" do
    create(:course, slug: "coding-fundamentals")
    user = create(:user)
    attribution = { "referrer" => "not a valid url" }

    User::Identify.stubs(:defer)
    Analytics::TrackEvent.expects(:defer).with(
      user,
      "user_signed_up",
      properties: {
        provider: "email",
        "referrer" => "not a valid url",
        "$referrer": "not a valid url",
        "$referring_domain": "$direct",
        "$set_once": {
          "$initial_referrer": "not a valid url",
          "$initial_referring_domain": "$direct"
        }
      }
    )

    User::Bootstrap.(user, "email", attribution: attribution)
  end

  test "does not touch user.data when attribution is nil" do
    create(:course, slug: "coding-fundamentals")
    user = create(:user)
    User::Identify.stubs(:defer)
    Analytics::TrackEvent.stubs(:defer)

    User::Bootstrap.(user, "email")

    assert_nil user.data.reload.signup_attribution
  end

  test "does not touch user.data when attribution is empty" do
    create(:course, slug: "coding-fundamentals")
    user = create(:user)
    User::Identify.stubs(:defer)
    Analytics::TrackEvent.stubs(:defer)

    User::Bootstrap.(user, "email", attribution: {})

    assert_nil user.data.reload.signup_attribution
  end
end
