require "test_helper"

class User::BootstrapTest < ActiveSupport::TestCase
  test "enqueues welcome email" do
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
    user = build(:user)
    user.save!

    assert_enqueued_jobs 1, only: MandateJob do
      User::Bootstrap.(user)
    end
  end

  # First level creation tests (when course is provided)
  test "creates user_course and user_level when course is provided" do
    course = create(:course)
    level1 = create(:level, course:, position: 1)
    create(:level, course:, position: 2)
    create(:level, course:, position: 3)
    user = create(:user)

    User::Bootstrap.(user, course:)

    user_course = UserCourse.find_by(user:, course:)
    refute_nil user_course
    user_level = UserLevel.find_by(user:, level: level1)
    refute_nil user_level
    assert_equal user_level.id, user_course.reload.current_user_level_id
  end

  test "calls UserCourse::Enroll and UserLevel::Start with first level" do
    user = create(:user)
    course = create(:course)
    level1 = create(:level, course:, position: 1)

    User::Bootstrap.(user, course:)

    assert UserCourse.exists?(user:, course:)
    assert UserLevel.exists?(user:, level: level1)
  end

  test "handles no course provided gracefully" do
    user = create(:user)

    assert_nothing_raised do
      User::Bootstrap.(user)
    end

    assert_equal 0, UserCourse.where(user:).count
    assert_equal 0, UserLevel.where(user:).count
  end

  test "uses lowest position level as first within course" do
    course = create(:course)
    level5 = create(:level, course:, position: 5)
    level10 = create(:level, course:, position: 10)
    level1 = create(:level, course:, position: 1)
    user = create(:user)

    User::Bootstrap.(user, course:)

    user_level = UserLevel.find_by(user:, level: level1)
    refute_nil user_level
    assert_nil UserLevel.find_by(user:, level: level5)
    assert_nil UserLevel.find_by(user:, level: level10)
  end

  # Badge tests
  test "enqueues member badge award job" do
    user = create(:user)

    assert_enqueued_with(job: AwardBadgeJob, args: [user, 'member']) do
      User::Bootstrap.(user)
    end
  end

  test "awards member badge to new user" do
    user = create(:user)

    perform_enqueued_jobs do
      User::Bootstrap.(user)
    end

    assert user.acquired_badges.joins(:badge).where(badges: { type: 'Badges::MemberBadge' }).exists?
  end
end
