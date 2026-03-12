require "test_helper"

class UserLevel::CompleteTest < ActiveSupport::TestCase
  test "sets completed_at to current time" do
    user_lesson = create(:user_lesson, :completed)
    user_level = UserLevel.find_by(user: user_lesson.user, level: user_lesson.lesson.level)

    time_before = Time.current
    UserLevel::Complete.(user_level)
    time_after = Time.current

    user_level.reload
    assert user_level.completed_at >= time_before
    assert user_level.completed_at <= time_after
  end

  test "is idempotent when completing already completed level" do
    user_lesson = create(:user_lesson, :completed)
    user_level = UserLevel.find_by(user: user_lesson.user, level: user_lesson.lesson.level)
    user_level.update!(completed_at: 1.day.ago)
    old_completed_at = user_level.completed_at

    UserLevel::Complete.(user_level)

    assert_equal old_completed_at.to_i, user_level.reload.completed_at.to_i
  end

  test "creates user_level for next level when next level exists" do
    user_course = create(:user_course)
    level1 = create(:level, course: user_course.course, position: 1)
    level2 = create(:level, course: user_course.course, position: 2)
    lesson = create(:lesson, :exercise, level: level1)
    user_level = create(:user_level, user: user_course.user, level: level1)
    create(:user_lesson, user: user_course.user, lesson:, completed_at: Time.current)

    UserLevel::Complete.(user_level)

    next_user_level = UserLevel.find_by(user: user_course.user, level: level2)
    refute_nil next_user_level
    refute_nil next_user_level.created_at
    assert_nil next_user_level.completed_at
  end

  test "does not create next user_level when no next level exists" do
    user_lesson = create(:user_lesson, :completed)
    user_level = UserLevel.find_by(user: user_lesson.user, level: user_lesson.lesson.level)

    UserLevel::Complete.(user_level)

    assert_equal 1, user_lesson.user.user_levels.count
  end

  test "creates next user_level with gaps in position numbers" do
    user_course = create(:user_course)
    level1 = create(:level, course: user_course.course, position: 1)
    level5 = create(:level, course: user_course.course, position: 5)
    lesson = create(:lesson, :exercise, level: level1)
    user_level = create(:user_level, user: user_course.user, level: level1)
    create(:user_lesson, user: user_course.user, lesson:, completed_at: Time.current)

    UserLevel::Complete.(user_level)

    next_user_level = UserLevel.find_by(user: user_course.user, level: level5)
    refute_nil next_user_level
    assert_equal level5, next_user_level.level
  end

  test "wraps completion and next level creation in transaction" do
    user_course = create(:user_course)
    level1 = create(:level, course: user_course.course, position: 1)
    create(:level, course: user_course.course, position: 2)
    lesson = create(:lesson, :exercise, level: level1)
    user_level = create(:user_level, user: user_course.user, level: level1)
    create(:user_lesson, user: user_course.user, lesson:, completed_at: Time.current)

    UserLevel::Start.stubs(:call).raises(ActiveRecord::RecordInvalid)

    assert_raises(ActiveRecord::RecordInvalid) do
      UserLevel::Complete.(user_level)
    end

    assert_nil user_level.reload.completed_at
  end

  test "sends completion email when email fields are configured" do
    user_level = create(:user_level)
    user_level.user.update!(locale: "en")
    lesson = create(:lesson, :exercise, level: user_level.level)
    create(:user_lesson, user: user_level.user, lesson:, completed_at: Time.current)

    # Level factory already includes email fields by default
    assert_enqueued_jobs 1, only: ActionMailer::MailDeliveryJob do
      UserLevel::Complete.(user_level)
    end
  end

  test "idempotency: does not create next level or send email on re-completion" do
    user_course = create(:user_course)
    user_course.user.update!(locale: "en")
    level1 = create(:level, course: user_course.course, position: 1)
    level2 = create(:level, course: user_course.course, position: 2)
    lesson = create(:lesson, :exercise, level: level1)
    user_level = create(:user_level, user: user_course.user, level: level1)
    create(:user_lesson, user: user_course.user, lesson:, completed_at: Time.current)

    UserLevel::Complete.(user_level)
    old_completed_at = user_level.reload.completed_at

    assert_equal 2, user_course.user.user_levels.count
    next_user_level = UserLevel.find_by(user: user_course.user, level: level2)
    refute_nil next_user_level

    assert_no_enqueued_jobs only: ActionMailer::MailDeliveryJob do
      assert_no_difference -> { user_course.user.user_levels.count } do
        UserLevel::Complete.(user_level)
        assert_equal old_completed_at.to_i, user_level.reload.completed_at.to_i
      end
    end
  end
end
