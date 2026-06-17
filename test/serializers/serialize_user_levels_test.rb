require "test_helper"

class SerializeUserLevelsTest < ActiveSupport::TestCase
  test "serializes user_levels with user_lessons" do
    user = create(:user)
    level1 = create(:level, slug: "basics", position: 1)
    level2 = create(:level, slug: "advanced", position: 2)

    lesson1 = create(:lesson, :exercise, level: level1, slug: "lesson-1", position: 1)
    lesson2 = create(:lesson, :exercise, level: level1, slug: "lesson-2", position: 2)
    lesson3 = create(:lesson, :exercise, level: level2, slug: "lesson-3", position: 1)

    create(:user_level, user: user, level: level1, completed_at: Time.current)
    create(:user_level, user: user, level: level2)

    create(:user_lesson, user: user, lesson: lesson1, completed_at: Time.current, walkthrough_video_watched_percentage: 100)
    create(:user_lesson, user: user, lesson: lesson2, completed_at: nil, walkthrough_video_watched_percentage: 42)
    create(:user_lesson, user: user, lesson: lesson3, completed_at: Time.current)

    expected = [
      {
        level_slug: "basics",
        status: "completed",
        user_lessons: [
          { lesson_slug: "lesson-1", status: "completed", walkthrough_video_watched_percentage: 100 },
          { lesson_slug: "lesson-2", status: "started", walkthrough_video_watched_percentage: 42 }
        ]
      },
      {
        level_slug: "advanced",
        status: "started",
        user_lessons: [
          { lesson_slug: "lesson-3", status: "completed", walkthrough_video_watched_percentage: nil }
        ]
      }
    ]

    assert_equal(expected, SerializeUserLevels.(user.user_levels))
  end

  test "returns empty array when no user_levels" do
    user = create(:user)

    assert_empty SerializeUserLevels.(user.user_levels)
  end

  test "no not_started lesson is appended while a lesson is in progress" do
    user = create(:user)
    level = create(:level, slug: "basics")

    lesson1 = create(:lesson, :exercise, level: level, slug: "lesson-1", position: 1)
    lesson2 = create(:lesson, :exercise, level: level, slug: "lesson-2", position: 2)
    create(:lesson, :exercise, level: level, slug: "lesson-3", position: 3)

    create(:user_level, user: user, level: level)
    create(:user_lesson, user: user, lesson: lesson1, completed_at: Time.current)
    create(:user_lesson, user: user, lesson: lesson2, completed_at: nil)

    # lesson-2 is in progress, so lesson-3 is NOT appended as not_started
    expected = [
      {
        level_slug: "basics",
        status: "started",
        user_lessons: [
          { lesson_slug: "lesson-1", status: "completed", walkthrough_video_watched_percentage: nil },
          { lesson_slug: "lesson-2", status: "started", walkthrough_video_watched_percentage: nil }
        ]
      }
    ]

    assert_equal(expected, SerializeUserLevels.(user.user_levels))
  end

  test "appends the next lesson as not_started mid-level when all started lessons are complete" do
    user = create(:user)
    level = create(:level, slug: "basics")

    lesson1 = create(:lesson, :exercise, level: level, slug: "lesson-1", position: 1)
    lesson2 = create(:lesson, :exercise, level: level, slug: "lesson-2", position: 2)
    create(:lesson, :exercise, level: level, slug: "lesson-3", position: 3)

    create(:user_level, user: user, level: level)
    create(:user_lesson, user: user, lesson: lesson1, completed_at: Time.current)
    create(:user_lesson, user: user, lesson: lesson2, completed_at: Time.current)

    # All started lessons complete, so the next lesson (lesson-3) is appended as not_started.
    # lesson-3 is the only not_started lesson - later lessons are not included.
    expected = [
      {
        level_slug: "basics",
        status: "started",
        user_lessons: [
          { lesson_slug: "lesson-1", status: "completed", walkthrough_video_watched_percentage: nil },
          { lesson_slug: "lesson-2", status: "completed", walkthrough_video_watched_percentage: nil },
          { lesson_slug: "lesson-3", status: "not_started", walkthrough_video_watched_percentage: nil }
        ]
      }
    ]

    assert_equal(expected, SerializeUserLevels.(user.user_levels))
  end

  test "appends the first lesson of a freshly-unlocked level (UserLevel, no UserLessons) as not_started" do
    user = create(:user)
    level1 = create(:level, slug: "basics", position: 1)
    level2 = create(:level, slug: "advanced", position: 2)

    lesson1 = create(:lesson, :exercise, level: level1, slug: "lesson-1", position: 1)
    create(:lesson, :exercise, level: level2, slug: "lesson-2", position: 1)
    create(:lesson, :exercise, level: level2, slug: "lesson-3", position: 2)

    create(:user_level, user: user, level: level1, completed_at: Time.current)
    create(:user_level, user: user, level: level2)
    create(:user_lesson, user: user, lesson: lesson1, completed_at: Time.current)

    # level2 has a UserLevel but no UserLessons yet (freshly unlocked).
    # Its first lesson (lesson-2) is appended as not_started; lesson-3 is not included.
    expected = [
      {
        level_slug: "basics",
        status: "completed",
        user_lessons: [
          { lesson_slug: "lesson-1", status: "completed", walkthrough_video_watched_percentage: nil }
        ]
      },
      {
        level_slug: "advanced",
        status: "started",
        user_lessons: [
          { lesson_slug: "lesson-2", status: "not_started", walkthrough_video_watched_percentage: nil }
        ]
      }
    ]

    assert_equal(expected, SerializeUserLevels.(user.user_levels))
  end

  test "does not append a not_started lesson to a completed level" do
    user = create(:user)
    level = create(:level, slug: "basics")

    lesson1 = create(:lesson, :exercise, level: level, slug: "lesson-1", position: 1)
    lesson2 = create(:lesson, :exercise, level: level, slug: "lesson-2", position: 2)
    # lesson-3 has no UserLesson record. Normal progression can't complete a level
    # with an unstarted lesson, but a completed level must never advertise a next
    # lesson even if content drifts.
    create(:lesson, :exercise, level: level, slug: "lesson-3", position: 3)

    create(:user_level, user: user, level: level, completed_at: Time.current)
    create(:user_lesson, user: user, lesson: lesson1, completed_at: Time.current)
    create(:user_lesson, user: user, lesson: lesson2, completed_at: Time.current)

    expected = [
      {
        level_slug: "basics",
        status: "completed",
        user_lessons: [
          { lesson_slug: "lesson-1", status: "completed", walkthrough_video_watched_percentage: nil },
          { lesson_slug: "lesson-2", status: "completed", walkthrough_video_watched_percentage: nil }
        ]
      }
    ]

    assert_equal(expected, SerializeUserLevels.(user.user_levels))
  end

  test "maintains level position order" do
    user = create(:user)
    level1 = create(:level, slug: "level-c", position: 3)
    level2 = create(:level, slug: "level-a", position: 1)
    level3 = create(:level, slug: "level-b", position: 2)

    lesson1 = create(:lesson, :exercise, level: level1, slug: "lesson-c")
    lesson2 = create(:lesson, :exercise, level: level2, slug: "lesson-a")
    lesson3 = create(:lesson, :exercise, level: level3, slug: "lesson-b")

    create(:user_level, user: user, level: level1)
    create(:user_level, user: user, level: level2)
    create(:user_level, user: user, level: level3)

    create(:user_lesson, user: user, lesson: lesson1)
    create(:user_lesson, user: user, lesson: lesson2)
    create(:user_lesson, user: user, lesson: lesson3)

    expected = [
      { level_slug: "level-a", status: "started",
        user_lessons: [{ lesson_slug: "lesson-a", status: "started", walkthrough_video_watched_percentage: nil }] },
      { level_slug: "level-b", status: "started",
        user_lessons: [{ lesson_slug: "lesson-b", status: "started", walkthrough_video_watched_percentage: nil }] },
      { level_slug: "level-c", status: "started",
        user_lessons: [{ lesson_slug: "lesson-c", status: "started", walkthrough_video_watched_percentage: nil }] }
    ]

    assert_equal(expected, SerializeUserLevels.(user.user_levels))
  end

  test "maintains lesson position order within levels" do
    user = create(:user)
    level = create(:level, slug: "basics")

    lesson1 = create(:lesson, :exercise, level: level, slug: "lesson-c", position: 3)
    lesson2 = create(:lesson, :exercise, level: level, slug: "lesson-a", position: 1)
    lesson3 = create(:lesson, :exercise, level: level, slug: "lesson-b", position: 2)

    create(:user_level, user: user, level: level)
    create(:user_lesson, user: user, lesson: lesson1)
    create(:user_lesson, user: user, lesson: lesson2)
    create(:user_lesson, user: user, lesson: lesson3)

    expected = [
      {
        level_slug: "basics",
        status: "started",
        user_lessons: [
          { lesson_slug: "lesson-a", status: "started", walkthrough_video_watched_percentage: nil },
          { lesson_slug: "lesson-b", status: "started", walkthrough_video_watched_percentage: nil },
          { lesson_slug: "lesson-c", status: "started", walkthrough_video_watched_percentage: nil }
        ]
      }
    ]

    assert_equal(expected, SerializeUserLevels.(user.user_levels))
  end
end
