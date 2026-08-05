require "test_helper"

class Curriculum::AppendLessonTest < ActiveSupport::TestCase
  ATTRS = {
    slug: "brand-new-exercise",
    type: "exercise"
  }.freeze

  test "appends the lesson at the end of the level" do
    level = create(:level)
    create(:lesson, :video, level:, position: 1)
    create(:lesson, :exercise, level:, position: 2)

    lesson = Curriculum::AppendLesson.(level, ATTRS)

    assert_equal level, lesson.level
    assert_equal 3, lesson.position
    assert_equal "brand-new-exercise", lesson.slug
  end

  test "does not reopen completed levels by default" do
    level = create(:level)
    create(:lesson, :exercise, level:)
    completed = create(:user_level, level:, completed_at: Time.current)

    Curriculum::AppendLesson.(level, ATTRS)

    assert completed.reload.completed_at.present?
  end

  test "reopens completed levels when reopen_completed is true" do
    level = create(:level)
    create(:lesson, :exercise, level:)
    completed = create(:user_level, level:, completed_at: Time.current)

    Curriculum::AppendLesson.(level, ATTRS, reopen_completed: true)

    assert_nil completed.reload.completed_at
  end

  test "reopening does not touch levels that were not completed" do
    level = create(:level)
    create(:lesson, :exercise, level:)
    in_progress = create(:user_level, level:, completed_at: nil)

    Curriculum::AppendLesson.(level, ATTRS, reopen_completed: true)

    assert_nil in_progress.reload.completed_at
  end

  test "reopening never moves current_user_level" do
    level = create(:level)
    next_level = create(:level, course: level.course, position: 99)
    create(:lesson, :exercise, level:)
    user = create(:user)
    user_course = create(:user_course, user:, course: level.course)
    create(:user_level, user:, level:, completed_at: Time.current)
    frontier = create(:user_level, user:, level: next_level)
    user_course.update!(current_user_level: frontier)

    Curriculum::AppendLesson.(level, ATTRS, reopen_completed: true)

    assert_equal frontier, user_course.reload.current_user_level
  end
end
