require "test_helper"

class Curriculum::ReorderLessonsTest < ActiveSupport::TestCase
  test "assigns positions from the given ordering" do
    level = create(:level)
    first = create(:lesson, :exercise, level:, position: 1, slug: "first")
    second = create(:lesson, :exercise, level:, position: 2, slug: "second")
    third = create(:lesson, :exercise, level:, position: 3, slug: "third")

    Curriculum::ReorderLessons.(level, %w[third first second])

    assert_equal 1, third.reload.position
    assert_equal 2, first.reload.position
    assert_equal 3, second.reload.position
  end

  test "leaves an unchanged ordering exactly as it was" do
    level = create(:level)
    first = create(:lesson, :exercise, level:, position: 1, slug: "first")
    second = create(:lesson, :exercise, level:, position: 2, slug: "second")

    Curriculum::ReorderLessons.(level, %w[first second])

    assert_equal 1, first.reload.position
    assert_equal 2, second.reload.position
  end

  test "does not touch lessons on other levels" do
    level = create(:level)
    create(:lesson, :exercise, level:, position: 1, slug: "first")
    create(:lesson, :exercise, level:, position: 2, slug: "second")
    other = create(:lesson, :exercise, level: create(:level, course: level.course, position: 2), position: 1)

    Curriculum::ReorderLessons.(level, %w[second first])

    assert_equal 1, other.reload.position
  end

  test "releases pointers stranded by the reorder" do
    level = create(:level)
    first = create(:lesson, :exercise, level:, position: 1, slug: "first")
    # The user is legitimately parked on position 2; the reorder demotes it.
    demoted = create(:lesson, :exercise, level:, position: 2, slug: "demoted")
    promoted = create(:lesson, :exercise, level:, position: 3, slug: "promoted")
    user = create(:user)
    create(:user_lesson, user:, lesson: first, completed_at: Time.current)
    parked = create(:user_lesson, user:, lesson: demoted, completed_at: nil)
    user_level = UserLevel.find_by!(user:, level:)
    user_level.update!(current_user_lesson: parked)

    Curriculum::ReorderLessons.(level, %w[first promoted demoted])

    assert_nil user_level.reload.current_user_lesson
    assert_equal 2, promoted.reload.position
    assert_equal 3, demoted.reload.position
  end

  test "leaves pointers that the reorder does not strand" do
    level = create(:level)
    first = create(:lesson, :exercise, level:, position: 1, slug: "first")
    second = create(:lesson, :exercise, level:, position: 2, slug: "second")
    user = create(:user)
    create(:user_lesson, user:, lesson: first, completed_at: Time.current)
    parked = create(:user_lesson, user:, lesson: second, completed_at: nil)
    user_level = UserLevel.find_by!(user:, level:)
    user_level.update!(current_user_lesson: parked)

    Curriculum::ReorderLessons.(level, %w[first second])

    assert_equal parked, user_level.reload.current_user_lesson
  end

  test "raises when the ordering omits a lesson" do
    level = create(:level)
    create(:lesson, :exercise, level:, position: 1, slug: "first")
    create(:lesson, :exercise, level:, position: 2, slug: "second")

    assert_raises(InvalidLessonOrderingError) do
      Curriculum::ReorderLessons.(level, %w[first])
    end
  end

  test "raises when the ordering names an unknown lesson" do
    level = create(:level)
    create(:lesson, :exercise, level:, position: 1, slug: "first")

    assert_raises(InvalidLessonOrderingError) do
      Curriculum::ReorderLessons.(level, %w[first nonsense])
    end
  end

  test "leaves positions untouched when the ordering is invalid" do
    level = create(:level)
    first = create(:lesson, :exercise, level:, position: 1, slug: "first")
    second = create(:lesson, :exercise, level:, position: 2, slug: "second")

    assert_raises(InvalidLessonOrderingError) do
      Curriculum::ReorderLessons.(level, %w[second])
    end

    assert_equal 1, first.reload.position
    assert_equal 2, second.reload.position
  end
end
