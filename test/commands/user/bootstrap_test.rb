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

  test "creates user_course and user_level for coding-fundamentals" do
    course = create(:course, slug: "coding-fundamentals")
    level1 = create(:level, course:, position: 1)
    create(:level, course:, position: 2)
    create(:level, course:, position: 3)
    user = create(:user)

    User::Bootstrap.(user)

    user_course = UserCourse.find_by(user:, course:)
    refute_nil user_course
    user_level = UserLevel.find_by(user:, level: level1)
    refute_nil user_level
    assert_equal user_level.id, user_course.reload.current_user_level_id
  end

  test "calls UserCourse::Enroll and UserLevel::Start with first level" do
    course = create(:course, slug: "coding-fundamentals")
    level1 = create(:level, course:, position: 1)
    user = create(:user)

    User::Bootstrap.(user)

    assert UserCourse.exists?(user:, course:)
    assert UserLevel.exists?(user:, level: level1)
  end

  test "uses lowest position level as first within course" do
    course = create(:course, slug: "coding-fundamentals")
    create(:level, course:, position: 5)
    create(:level, course:, position: 10)
    level1 = create(:level, course:, position: 1)
    user = create(:user)

    User::Bootstrap.(user)

    user_level = UserLevel.find_by(user:, level: level1)
    refute_nil user_level
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
