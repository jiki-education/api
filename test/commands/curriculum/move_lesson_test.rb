require "test_helper"

class Curriculum::MoveLessonTest < ActiveSupport::TestCase
  test "moves the lesson to the end of the destination level" do
    source = create(:level, position: 1)
    destination = create(:level, course: source.course, position: 2)
    create(:lesson, :video, level: destination, position: 1)
    lesson = create(:lesson, :exercise, level: source, position: 1)

    Curriculum::MoveLesson.(lesson, destination)

    lesson.reload
    assert_equal destination, lesson.level
    assert_equal 2, lesson.position
  end

  test "completes the source level for users whose remaining lessons are now all done" do
    source = create(:level, position: 1)
    destination = create(:level, course: source.course, position: 2)
    keeper = create(:lesson, :exercise, level: source, position: 1)
    mover = create(:lesson, :exercise, level: source, position: 2)
    user = create(:user)
    user_course = create(:user_course, user:, course: source.course)
    source_ul = create(:user_level, user:, level: source)
    user_course.update!(current_user_level: source_ul)
    create(:user_lesson, user:, lesson: keeper, completed_at: Time.current)

    Curriculum::MoveLesson.(mover, destination)

    assert source_ul.reload.completed_at.present?
    destination_ul = UserLevel.find_by(user:, level: destination)
    assert_equal destination_ul, user_course.reload.current_user_level
  end

  test "does not complete the source level when remaining lessons are still outstanding" do
    source = create(:level, position: 1)
    destination = create(:level, course: source.course, position: 2)
    create(:lesson, :exercise, level: source, position: 1) # keeper, not completed
    mover = create(:lesson, :exercise, level: source, position: 2)
    user = create(:user)
    create(:user_course, user:, course: source.course)
    source_ul = create(:user_level, user:, level: source)

    Curriculum::MoveLesson.(mover, destination)

    assert_nil source_ul.reload.completed_at
  end

  test "does not move current_user_level backwards when completing the source level" do
    source = create(:level, position: 1)
    mid = create(:level, course: source.course, position: 2)
    keeper = create(:lesson, :exercise, level: source, position: 1)
    mover = create(:lesson, :exercise, level: source, position: 2)
    user = create(:user)
    user_course = create(:user_course, user:, course: source.course)
    source_ul = create(:user_level, user:, level: source)
    frontier = create(:user_level, user:, level: mid)
    user_course.update!(current_user_level: frontier)
    create(:user_lesson, user:, lesson: keeper, completed_at: Time.current)

    Curriculum::MoveLesson.(mover, mid)

    assert source_ul.reload.completed_at.present?
    assert_equal frontier, user_course.reload.current_user_level
  end

  test "backfills a destination user_level for users who progressed on the moved lesson" do
    source = create(:level, position: 1)
    destination = create(:level, course: source.course, position: 2)
    create(:lesson, :exercise, level: source, position: 2) # keeper, keeps source non-empty & incomplete
    mover = create(:lesson, :exercise, level: source, position: 1)
    user = create(:user)
    user_course = create(:user_course, user:, course: source.course)
    frontier = create(:user_level, user:, level: create(:level, course: source.course, position: 3))
    user_course.update!(current_user_level: frontier)
    create(:user_lesson, user:, lesson: mover, completed_at: Time.current)
    refute UserLevel.exists?(user:, level: destination)

    Curriculum::MoveLesson.(mover, destination)

    destination_ul = UserLevel.find_by(user:, level: destination)
    refute_nil destination_ul
    assert_nil destination_ul.completed_at
  end

  test "does not duplicate an existing destination user_level" do
    source = create(:level, position: 1)
    destination = create(:level, course: source.course, position: 2)
    create(:lesson, :exercise, level: source, position: 2) # keeper
    mover = create(:lesson, :exercise, level: source, position: 1)
    user = create(:user)
    create(:user_course, user:, course: source.course)
    existing = create(:user_level, user:, level: destination)
    create(:user_lesson, user:, lesson: mover, completed_at: Time.current)

    Curriculum::MoveLesson.(mover, destination)

    assert_equal [existing], UserLevel.where(user:, level: destination).to_a
  end

  test "does not reopen a completed destination by default" do
    source = create(:level, position: 1)
    destination = create(:level, course: source.course, position: 2)
    mover = create(:lesson, :exercise, level: source, position: 1)
    user = create(:user)
    create(:user_course, user:, course: source.course)
    destination_ul = create(:user_level, user:, level: destination, completed_at: Time.current)

    Curriculum::MoveLesson.(mover, destination)

    assert destination_ul.reload.completed_at.present?
  end

  test "reopens a completed destination when reopen_completed is true" do
    source = create(:level, position: 1)
    destination = create(:level, course: source.course, position: 2)
    mover = create(:lesson, :exercise, level: source, position: 1)
    user = create(:user)
    create(:user_course, user:, course: source.course)
    destination_ul = create(:user_level, user:, level: destination, completed_at: Time.current)

    Curriculum::MoveLesson.(mover, destination, reopen_completed: true)

    assert_nil destination_ul.reload.completed_at
  end

  test "does not backfill a destination user_level ahead of the user's frontier" do
    source = create(:level, position: 1)
    destination = create(:level, course: source.course, position: 3)
    create(:lesson, :exercise, level: source, position: 2) # keeper
    mover = create(:lesson, :exercise, level: source, position: 1)
    user = create(:user)
    user_course = create(:user_course, user:, course: source.course)
    frontier = create(:user_level, user:, level: source)
    user_course.update!(current_user_level: frontier)
    create(:user_lesson, user:, lesson: mover, completed_at: Time.current)

    Curriculum::MoveLesson.(mover, destination)

    refute UserLevel.exists?(user:, level: destination)
    assert_equal frontier, user_course.reload.current_user_level
  end
end
