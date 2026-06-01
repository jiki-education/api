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
    attribution = { "utm_source" => "twitter", "referrer" => "https://t.co/foo" }

    User::Identify.expects(:defer).with(user)
    Analytics::TrackEvent.expects(:defer).with(
      user,
      "user_signed_up",
      properties: { provider: "google", "utm_source" => "twitter", "referrer" => "https://t.co/foo" }
    )

    User::Bootstrap.(user, "google", attribution: attribution)

    assert_equal attribution, user.data.reload.signup_attribution
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
