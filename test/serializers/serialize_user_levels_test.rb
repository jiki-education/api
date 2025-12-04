require "test_helper"

class SerializeUserLevelsTest < ActiveSupport::TestCase
  test "serializes user_levels with user_lessons" do
    user = create(:user)
    level1 = create(:level, slug: "basics", position: 1)
    level2 = create(:level, slug: "advanced", position: 2)

    lesson1 = create(:lesson, level: level1, slug: "lesson-1", position: 1)
    lesson2 = create(:lesson, level: level1, slug: "lesson-2", position: 2)
    lesson3 = create(:lesson, level: level2, slug: "lesson-3", position: 1)

    create(:user_level, user: user, level: level1, completed_at: Time.current)
    create(:user_level, user: user, level: level2)

    create(:user_lesson, user: user, lesson: lesson1, completed_at: Time.current)
    create(:user_lesson, user: user, lesson: lesson2, completed_at: nil)
    create(:user_lesson, user: user, lesson: lesson3, completed_at: Time.current)

    expected = [
      {
        level_slug: "basics",
        status: "completed",
        user_lessons: [
          { lesson_slug: "lesson-1", status: "completed" },
          { lesson_slug: "lesson-2", status: "started" }
        ]
      },
      {
        level_slug: "advanced",
        status: "started",
        user_lessons: [
          { lesson_slug: "lesson-3", status: "completed" }
        ]
      }
    ]

    assert_equal(expected, SerializeUserLevels.(user.user_levels))
  end

  test "returns empty array when no user_levels" do
    user = create(:user)

    assert_empty SerializeUserLevels.(user.user_levels)
  end

  test "excludes levels with no user_lessons" do
    user = create(:user)
    level = create(:level, slug: "empty-level")
    create(:user_level, user: user, level: level)
    create(:lesson, level: level, slug: "lesson-1")

    assert_empty SerializeUserLevels.(user.user_levels)
  end

  test "maintains level position order" do
    user = create(:user)
    level1 = create(:level, slug: "level-c", position: 3)
    level2 = create(:level, slug: "level-a", position: 1)
    level3 = create(:level, slug: "level-b", position: 2)

    lesson1 = create(:lesson, level: level1, slug: "lesson-c")
    lesson2 = create(:lesson, level: level2, slug: "lesson-a")
    lesson3 = create(:lesson, level: level3, slug: "lesson-b")

    create(:user_level, user: user, level: level1)
    create(:user_level, user: user, level: level2)
    create(:user_level, user: user, level: level3)

    create(:user_lesson, user: user, lesson: lesson1)
    create(:user_lesson, user: user, lesson: lesson2)
    create(:user_lesson, user: user, lesson: lesson3)

    expected = [
      { level_slug: "level-a", status: "started", user_lessons: [{ lesson_slug: "lesson-a", status: "started" }] },
      { level_slug: "level-b", status: "started", user_lessons: [{ lesson_slug: "lesson-b", status: "started" }] },
      { level_slug: "level-c", status: "started", user_lessons: [{ lesson_slug: "lesson-c", status: "started" }] }
    ]

    assert_equal(expected, SerializeUserLevels.(user.user_levels))
  end

  test "maintains lesson position order within levels" do
    user = create(:user)
    level = create(:level, slug: "basics")

    lesson1 = create(:lesson, level: level, slug: "lesson-c", position: 3)
    lesson2 = create(:lesson, level: level, slug: "lesson-a", position: 1)
    lesson3 = create(:lesson, level: level, slug: "lesson-b", position: 2)

    create(:user_level, user: user, level: level)
    create(:user_lesson, user: user, lesson: lesson1)
    create(:user_lesson, user: user, lesson: lesson2)
    create(:user_lesson, user: user, lesson: lesson3)

    expected = [
      {
        level_slug: "basics",
        status: "started",
        user_lessons: [
          { lesson_slug: "lesson-a", status: "started" },
          { lesson_slug: "lesson-b", status: "started" },
          { lesson_slug: "lesson-c", status: "started" }
        ]
      }
    ]

    assert_equal(expected, SerializeUserLevels.(user.user_levels))
  end
end
