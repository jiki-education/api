require "test_helper"

class User::BootstrapTest < ActiveSupport::TestCase
  test "enqueues welcome email" do
    create(:course, slug: "coding-fundamentals")
    user = create(:user)

    assert_enqueued_with(
      job: MandateJob,
      args: ["User::SendWelcomeEmail", user],
      queue: "mailers"
    ) do
      User::Bootstrap.(user)
    end
  end

  test "works with newly created user" do
    create(:course, slug: "coding-fundamentals")
    user = build(:user)
    user.save!

    assert_enqueued_jobs 1, only: MandateJob do
      User::Bootstrap.(user)
    end
  end

  test "enrolls user in coding-fundamentals course" do
    course = create(:course, slug: "coding-fundamentals")
    user = create(:user)

    User::Bootstrap.(user)

    assert UserCourse.exists?(user:, course:)
  end

  test "enqueues member badge award job" do
    create(:course, slug: "coding-fundamentals")
    user = create(:user)

    assert_enqueued_with(job: AwardBadgeJob, args: [user, 'member']) do
      User::Bootstrap.(user)
    end
  end

  test "awards member badge to new user" do
    create(:course, slug: "coding-fundamentals")
    user = create(:user)

    perform_enqueued_jobs do
      User::Bootstrap.(user)
    end

    assert user.acquired_badges.joins(:badge).where(badges: { type: 'Badges::MemberBadge' }).exists?
  end
end
