require "test_helper"

class UserLesson::CompleteTest < ActiveSupport::TestCase
  test "completes existing user_lesson" do
    user = create(:user)
    level = create(:level)
    lesson = create(:lesson, :exercise, level:)
    create(:user_level, user:, level:)
    user_lesson = create(:user_lesson, user:, lesson:)

    result = UserLesson::Complete.(user, lesson)

    assert_equal user_lesson.id, result.id
    assert result.completed_at.present?
  end

  test "raises error if user_lesson doesn't exist" do
    user = create(:user)
    lesson = create(:lesson, :exercise)

    assert_raises(UserLessonNotFoundError) do
      UserLesson::Complete.(user, lesson)
    end
  end

  test "sets completed_at to current time" do
    user = create(:user)
    level = create(:level)
    lesson = create(:lesson, :exercise, level:)
    create(:user_level, user:, level:)
    create(:user_lesson, user:, lesson:)

    time_before = Time.current
    user_lesson = UserLesson::Complete.(user, lesson)
    time_after = Time.current

    assert user_lesson.completed_at >= time_before
    assert user_lesson.completed_at <= time_after
  end

  test "is idempotent when completing already completed lesson" do
    user = create(:user)
    level = create(:level)
    lesson = create(:lesson, :exercise, level:)
    create(:user_level, user:, level:)
    user_lesson = create(:user_lesson, user:, lesson:, completed_at: 1.day.ago)
    old_completed_at = user_lesson.completed_at

    result = UserLesson::Complete.(user, lesson)

    # Timestamp should not change on re-completion (idempotent)
    assert_equal old_completed_at.to_i, result.completed_at.to_i
  end

  test "delegates to UserLesson::Find for lookup" do
    user = create(:user)
    level = create(:level)
    lesson = create(:lesson, :exercise, level:)
    create(:user_level, user:, level:)
    user_lesson = create(:user_lesson, user:, lesson:)

    UserLesson::Find.expects(:call).with(user, lesson).returns(user_lesson)

    UserLesson::Complete.(user, lesson)
  end

  test "returns the completed user_lesson" do
    user = create(:user)
    level = create(:level)
    lesson = create(:lesson, :exercise, level:)
    create(:user_level, user:, level:)
    create(:user_lesson, user:, lesson:)

    result = UserLesson::Complete.(user, lesson)

    assert_instance_of UserLesson, result
    assert result.completed_at.present?
  end

  test "preserves created_at when completing" do
    user = create(:user)
    level = create(:level)
    lesson = create(:lesson, :exercise, level:)
    create(:user_level, user:, level:)
    created_time = 2.days.ago
    user_lesson = create(:user_lesson, user:, lesson:)
    user_lesson.update_column(:created_at, created_time)

    result = UserLesson::Complete.(user, lesson)

    assert_equal created_time.to_i, result.created_at.to_i
  end

  test "clears current_user_lesson on user_level when completing" do
    user = create(:user)
    level = create(:level)
    lesson = create(:lesson, :exercise, level:)
    user_level = create(:user_level, user:, level:)
    user_lesson = create(:user_lesson, user:, lesson:)
    user_level.update!(current_user_lesson: user_lesson)

    UserLesson::Complete.(user, lesson)

    assert_nil user_level.reload.current_user_lesson_id
  end

  test "raises error if user_level doesn't exist" do
    user = create(:user)
    lesson = create(:lesson, :exercise)
    # Manually create user_lesson without going through factory's after_build
    # which auto-creates user_level
    create(:user_course, user:, course: lesson.level.course)
    UserLesson.create!(user:, lesson:)

    assert_raises(UserLevelNotFoundError) do
      UserLesson::Complete.(user, lesson)
    end
  end

  test "clears existing current_user_lesson on user_level" do
    user_level = create(:user_level)
    lesson1 = create(:lesson, :exercise, level: user_level.level, slug: "first-lesson")
    lesson2 = create(:lesson, :exercise, level: user_level.level, slug: "second-lesson")
    user_lesson1 = create(:user_lesson, user: user_level.user, lesson: lesson1)
    create(:user_lesson, user: user_level.user, lesson: lesson2)
    user_level.update!(current_user_lesson: user_lesson1)

    UserLesson::Complete.(user_level.user, lesson2)

    user_level.reload
    assert_nil user_level.current_user_lesson_id
  end

  test "unlocks concept when lesson has unlocked_concept" do
    user = create(:user)
    level = create(:level)
    concept = create(:concept)
    lesson = create(:lesson, :exercise, level:)
    concept.update!(unlocked_by_lesson: lesson)
    create(:user_level, user:, level:)
    create(:user_lesson, user:, lesson:)

    assert_difference -> { user.data.reload.unlocked_concept_ids.length }, 1 do
      UserLesson::Complete.(user, lesson)
    end

    assert_includes user.data.unlocked_concept_ids, concept.id
  end

  test "does not unlock concept when lesson has no unlocked_concept" do
    user = create(:user)
    level = create(:level)
    lesson = create(:lesson, :exercise, level:)
    create(:user_level, user:, level:)
    create(:user_lesson, user:, lesson:)

    assert_no_difference -> { user.data.reload.unlocked_concept_ids.length } do
      UserLesson::Complete.(user, lesson)
    end
  end

  test "concept unlocking is idempotent" do
    user = create(:user)
    level = create(:level)
    concept = create(:concept)
    lesson = create(:lesson, :exercise, level:)
    concept.update!(unlocked_by_lesson: lesson)
    create(:user_level, user:, level:)
    create(:user_lesson, user:, lesson:)

    # Complete lesson twice
    UserLesson::Complete.(user, lesson)
    initial_count = user.data.unlocked_concept_ids.length

    assert_no_difference -> { user.data.reload.unlocked_concept_ids.length } do
      UserLesson::Complete.(user, lesson)
    end

    assert_equal initial_count, user.data.unlocked_concept_ids.length
  end

  test "unlocks project when lesson has unlocked_project" do
    user = create(:user)
    level = create(:level)
    project = create(:project)
    lesson = create(:lesson, :exercise, level:)
    project.update!(unlocked_by_lesson: lesson)
    create(:user_level, user:, level:)
    create(:user_lesson, user:, lesson:)

    assert_difference -> { user.user_projects.count }, 1 do
      UserLesson::Complete.(user, lesson)
    end

    assert_includes user.projects, project
  end

  test "does not unlock project when lesson has no unlocked_project" do
    user = create(:user)
    level = create(:level)
    lesson = create(:lesson, :exercise, level:)
    create(:user_level, user:, level:)
    create(:user_lesson, user:, lesson:)

    assert_no_difference -> { user.user_projects.count } do
      UserLesson::Complete.(user, lesson)
    end
  end

  test "project unlocking is idempotent" do
    user = create(:user)
    level = create(:level)
    project = create(:project)
    lesson = create(:lesson, :exercise, level:)
    project.update!(unlocked_by_lesson: lesson)
    create(:user_level, user:, level:)
    create(:user_lesson, user:, lesson:)

    # Complete lesson twice
    UserLesson::Complete.(user, lesson)
    initial_count = user.user_projects.count

    assert_no_difference -> { user.user_projects.count } do
      UserLesson::Complete.(user, lesson)
    end

    assert_equal initial_count, user.user_projects.count
  end

  # Badge tests
  test "enqueues maze navigator badge job on lesson completion" do
    user = create(:user)
    level = create(:level)
    lesson = create(:lesson, :exercise, level:)
    create(:user_level, user:, level:)
    create(:user_lesson, user:, lesson:)

    assert_enqueued_with(job: AwardBadgeJob, args: [user, 'maze_navigator']) do
      UserLesson::Complete.(user, lesson)
    end
  end

  test "awards maze navigator badge only when criteria is met" do
    user = create(:user)
    level = create(:level)
    lesson = create(:lesson, :exercise, level:, slug: 'maze-solve-basic')
    create(:user_level, user:, level:)
    create(:user_lesson, user:, lesson:)

    perform_enqueued_jobs do
      UserLesson::Complete.(user, lesson)
    end

    assert user.acquired_badges.joins(:badge).where(badges: { type: 'Badges::MazeNavigatorBadge' }).exists?
  end

  test "does not award maze navigator badge when criteria is not met" do
    user = create(:user)
    level = create(:level)
    lesson = create(:lesson, :exercise, level:, slug: 'some-other-lesson')
    create(:user_level, user:, level:)
    create(:user_lesson, user:, lesson:)

    perform_enqueued_jobs do
      UserLesson::Complete.(user, lesson)
    end

    refute user.acquired_badges.joins(:badge).where(badges: { type: 'Badges::MazeNavigatorBadge' }).exists?
  end

  # Lesson unlocked event tests
  test "emits lesson_unlocked event when there is a next lesson in the level" do
    user = create(:user)
    level = create(:level)
    lesson1 = create(:lesson, :exercise, level:, slug: "first-lesson", position: 1)
    create(:lesson, :exercise, level:, slug: "second-lesson", position: 2)
    create(:user_level, user:, level:)
    create(:user_lesson, user:, lesson: lesson1)

    Current.reset
    UserLesson::Complete.(user, lesson1)

    events = Current.events
    lesson_unlocked_events = events.select { |e| e[:type] == "lesson_unlocked" }
    assert_equal 1, lesson_unlocked_events.length
    assert_equal "second-lesson", lesson_unlocked_events.first[:data][:lesson_slug]
  end

  test "does not emit lesson_unlocked event when it is the last lesson in the level" do
    user = create(:user)
    level = create(:level)
    lesson = create(:lesson, :exercise, level:, slug: "only-lesson", position: 1)
    create(:user_level, user:, level:)
    create(:user_lesson, user:, lesson:)

    Current.reset
    UserLesson::Complete.(user, lesson)

    events = Current.events || []
    lesson_unlocked_events = events.select { |e| e[:type] == "lesson_unlocked" }
    assert_equal 0, lesson_unlocked_events.length
  end

  test "lesson_unlocked event contains correct slug for next lesson by position" do
    user = create(:user)
    level = create(:level)
    create(:lesson, :exercise, level:, slug: "lesson-one", position: 1)
    lesson2 = create(:lesson, :exercise, level:, slug: "lesson-two", position: 2)
    create(:lesson, :exercise, level:, slug: "lesson-three", position: 3)
    create(:user_level, user:, level:)
    create(:user_lesson, user:, lesson: lesson2)

    Current.reset
    UserLesson::Complete.(user, lesson2)

    events = Current.events
    lesson_unlocked_event = events.find { |e| e[:type] == "lesson_unlocked" }
    assert_equal "lesson-three", lesson_unlocked_event[:data][:lesson_slug]
  end

  test "does not emit lesson_unlocked event for next level's lessons" do
    user = create(:user)
    level1 = create(:level, position: 1, slug: "level-one")
    level2 = create(:level, position: 2, slug: "level-two")
    lesson1 = create(:lesson, :exercise, level: level1, slug: "level1-lesson", position: 1)
    create(:lesson, :exercise, level: level2, slug: "level2-lesson", position: 1)
    create(:user_level, user:, level: level1)
    create(:user_lesson, user:, lesson: lesson1)

    Current.reset
    UserLesson::Complete.(user, lesson1)

    events = Current.events || []
    lesson_unlocked_events = events.select { |e| e[:type] == "lesson_unlocked" }
    assert_equal 0, lesson_unlocked_events.length
  end
end
