require "test_helper"

class UserLesson::CompleteTest < ActiveSupport::TestCase
  test "completes existing user_lesson" do
    user = create(:user)
    lesson = create(:lesson)
    user_lesson = create(:user_lesson, user: user, lesson: lesson)

    result = UserLesson::Complete.(user, lesson)

    assert_equal user_lesson.id, result.id
    assert result.completed_at.present?
  end

  test "creates and completes user_lesson if it doesn't exist" do
    user = create(:user)
    lesson = create(:lesson)

    user_lesson = UserLesson::Complete.(user, lesson)

    assert user_lesson.persisted?
    assert_equal user.id, user_lesson.user_id
    assert_equal lesson.id, user_lesson.lesson_id
    assert user_lesson.started_at.present?
    assert user_lesson.completed_at.present?
  end

  test "sets completed_at to current time" do
    user = create(:user)
    lesson = create(:lesson)

    time_before = Time.current
    user_lesson = UserLesson::Complete.(user, lesson)
    time_after = Time.current

    assert user_lesson.completed_at >= time_before
    assert user_lesson.completed_at <= time_after
  end

  test "is idempotent when completing already completed lesson" do
    user = create(:user)
    lesson = create(:lesson)
    user_lesson = create(:user_lesson, user: user, lesson: lesson, completed_at: 1.day.ago)
    old_completed_at = user_lesson.completed_at

    result = UserLesson::Complete.(user, lesson)

    # Timestamp should not change on re-completion (idempotent)
    assert_equal old_completed_at.to_i, result.completed_at.to_i
  end

  test "delegates to UserLesson::FindOrCreate for find or create logic" do
    user = create(:user)
    lesson = create(:lesson)
    user_lesson = create(:user_lesson, user: user, lesson: lesson)

    UserLesson::FindOrCreate.expects(:call).with(user, lesson).returns(user_lesson)

    UserLesson::Complete.(user, lesson)
  end

  test "returns the completed user_lesson" do
    user = create(:user)
    lesson = create(:lesson)

    result = UserLesson::Complete.(user, lesson)

    assert_instance_of UserLesson, result
    assert result.completed_at.present?
  end

  test "preserves started_at when completing" do
    user = create(:user)
    lesson = create(:lesson)
    started_time = 2.days.ago
    create(:user_lesson, user: user, lesson: lesson, started_at: started_time)

    result = UserLesson::Complete.(user, lesson)

    assert_equal started_time.to_i, result.started_at.to_i
  end

  test "clears current_user_lesson on user_level when completing" do
    user = create(:user)
    lesson = create(:lesson)

    UserLesson::Complete.(user, lesson)

    user_level = UserLevel.find_by(user: user, level: lesson.level)
    assert_nil user_level.current_user_lesson_id
  end

  test "creates user_level if it doesn't exist when completing" do
    user = create(:user)
    lesson = create(:lesson)

    UserLesson::Complete.(user, lesson)

    user_level = UserLevel.find_by(user: user, level: lesson.level)
    assert user_level.present?
    assert_nil user_level.current_user_lesson_id
  end

  test "clears existing current_user_lesson on user_level" do
    user = create(:user)
    level = create(:level)
    lesson1 = create(:lesson, level: level, slug: "first-lesson")
    lesson2 = create(:lesson, level: level, slug: "second-lesson")
    user_lesson1 = create(:user_lesson, user: user, lesson: lesson1)
    user_level = create(:user_level, user: user, level: level, current_user_lesson: user_lesson1)

    UserLesson::Complete.(user, lesson2)

    user_level.reload
    assert_nil user_level.current_user_lesson_id
  end

  test "unlocks concept when lesson has unlocked_concept" do
    user = create(:user)
    concept = create(:concept)
    lesson = create(:lesson)
    concept.update!(unlocked_by_lesson: lesson)

    assert_difference -> { user.data.reload.unlocked_concept_ids.length }, 1 do
      UserLesson::Complete.(user, lesson)
    end

    assert_includes user.data.unlocked_concept_ids, concept.id
  end

  test "does not unlock concept when lesson has no unlocked_concept" do
    user = create(:user)
    lesson = create(:lesson)

    assert_no_difference -> { user.data.reload.unlocked_concept_ids.length } do
      UserLesson::Complete.(user, lesson)
    end
  end

  test "concept unlocking is idempotent" do
    user = create(:user)
    concept = create(:concept)
    lesson = create(:lesson)
    concept.update!(unlocked_by_lesson: lesson)

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
    project = create(:project)
    lesson = create(:lesson)
    project.update!(unlocked_by_lesson: lesson)

    assert_difference -> { user.user_projects.count }, 1 do
      UserLesson::Complete.(user, lesson)
    end

    assert_includes user.projects, project
  end

  test "does not unlock project when lesson has no unlocked_project" do
    user = create(:user)
    lesson = create(:lesson)

    assert_no_difference -> { user.user_projects.count } do
      UserLesson::Complete.(user, lesson)
    end
  end

  test "project unlocking is idempotent" do
    user = create(:user)
    project = create(:project)
    lesson = create(:lesson)
    project.update!(unlocked_by_lesson: lesson)

    # Complete lesson twice
    UserLesson::Complete.(user, lesson)
    initial_count = user.user_projects.count

    assert_no_difference -> { user.user_projects.count } do
      UserLesson::Complete.(user, lesson)
    end

    assert_equal initial_count, user.user_projects.count
  end
end
