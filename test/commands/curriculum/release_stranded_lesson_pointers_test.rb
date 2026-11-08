require "test_helper"

class Curriculum::ReleaseStrandedLessonPointersTest < ActiveSupport::TestCase
  test "releases a pointer left behind an incomplete earlier lesson" do
    level = create(:level)
    earlier = create(:lesson, :exercise, level:, position: 1)
    later = create(:lesson, :exercise, level:, position: 2)
    user = create(:user)
    parked = create(:user_lesson, user:, lesson: later, completed_at: nil)
    user_level = UserLevel.find_by!(user:, level:)
    user_level.update!(current_user_lesson: parked)

    Curriculum::ReleaseStrandedLessonPointers.(level)

    assert_nil user_level.reload.current_user_lesson
    # The user's work on the lesson they were parked on is untouched.
    assert UserLesson.exists?(user:, lesson: later)
    refute UserLesson.exists?(user:, lesson: earlier)
  end

  test "leaves a pointer alone when every earlier lesson is complete" do
    level = create(:level)
    earlier = create(:lesson, :exercise, level:, position: 1)
    later = create(:lesson, :exercise, level:, position: 2)
    user = create(:user)
    create(:user_lesson, user:, lesson: earlier, completed_at: Time.current)
    parked = create(:user_lesson, user:, lesson: later, completed_at: nil)
    user_level = UserLevel.find_by!(user:, level:)
    user_level.update!(current_user_lesson: parked)

    Curriculum::ReleaseStrandedLessonPointers.(level)

    assert_equal parked, user_level.reload.current_user_lesson
  end

  test "leaves a completed pointer alone" do
    level = create(:level)
    create(:lesson, :exercise, level:, position: 1)
    later = create(:lesson, :exercise, level:, position: 2)
    user = create(:user)
    parked = create(:user_lesson, user:, lesson: later, completed_at: Time.current)
    user_level = UserLevel.find_by!(user:, level:)
    user_level.update!(current_user_lesson: parked)

    Curriculum::ReleaseStrandedLessonPointers.(level)

    assert_equal parked, user_level.reload.current_user_lesson
  end

  test "ignores user levels with no pointer" do
    level = create(:level)
    create(:lesson, :exercise, level:, position: 1)
    user_level = create(:user_level, level:, current_user_lesson: nil)

    Curriculum::ReleaseStrandedLessonPointers.(level)

    assert_nil user_level.reload.current_user_lesson
  end

  test "ignores other levels" do
    level = create(:level)
    create(:lesson, :exercise, level:, position: 1)
    other_level = create(:level, course: level.course, position: 2)
    create(:lesson, :exercise, level: other_level, position: 1)
    later = create(:lesson, :exercise, level: other_level, position: 2)
    user = create(:user)
    parked = create(:user_lesson, user:, lesson: later, completed_at: nil)
    other_user_level = UserLevel.find_by!(user:, level: other_level)
    other_user_level.update!(current_user_lesson: parked)

    Curriculum::ReleaseStrandedLessonPointers.(level)

    assert_equal parked, other_user_level.reload.current_user_lesson
  end

  test "another user's completions do not rescue a stranded pointer" do
    level = create(:level)
    earlier = create(:lesson, :exercise, level:, position: 1)
    later = create(:lesson, :exercise, level:, position: 2)
    create(:user_lesson, lesson: earlier, completed_at: Time.current)
    user = create(:user)
    parked = create(:user_lesson, user:, lesson: later, completed_at: nil)
    user_level = UserLevel.find_by!(user:, level:)
    user_level.update!(current_user_lesson: parked)

    Curriculum::ReleaseStrandedLessonPointers.(level)

    assert_nil user_level.reload.current_user_lesson
  end

  test "releases several stranded users in one pass" do
    level = create(:level)
    create(:lesson, :exercise, level:, position: 1)
    later = create(:lesson, :exercise, level:, position: 2)
    user_levels = Prosopite.pause do
      Array.new(3) do
        user = create(:user)
        parked = create(:user_lesson, user:, lesson: later, completed_at: nil)
        UserLevel.find_by!(user:, level:).tap { |ul| ul.update!(current_user_lesson: parked) }
      end
    end

    Curriculum::ReleaseStrandedLessonPointers.(level)

    assert_equal 0, UserLevel.where(id: user_levels.map(&:id)).where.not(current_user_lesson_id: nil).count
  end
end
