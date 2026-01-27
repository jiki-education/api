require "test_helper"

class Internal::UserLevelsControllerTest < ApplicationControllerTest
  setup do
    setup_user
    @course = create(:course, slug: "test-course")
  end

  # Authentication guards
  guard_incorrect_token! :internal_user_levels_path, args: [{ course_slug: "test-course" }], method: :get do
    create(:course, slug: "test-course")
  end

  test "GET index returns all user_levels with nested user_lessons for course" do
    level1 = create(:level, course: @course, slug: "basics", position: 1)
    level2 = create(:level, course: @course, slug: "advanced", position: 2)

    lesson1 = create(:lesson, :exercise, level: level1, slug: "lesson-1", position: 1)
    lesson2 = create(:lesson, :exercise, level: level1, slug: "lesson-2", position: 2)
    lesson3 = create(:lesson, :exercise, level: level2, slug: "lesson-3", position: 1)

    create(:user_course, user: @current_user, course: @course)
    create(:user_level, user: @current_user, level: level1)
    create(:user_level, user: @current_user, level: level2)

    create(:user_lesson, user: @current_user, lesson: lesson1, completed_at: Time.current)
    create(:user_lesson, user: @current_user, lesson: lesson2, completed_at: nil)
    create(:user_lesson, user: @current_user, lesson: lesson3, completed_at: Time.current)

    get internal_user_levels_path(course_slug: @course.slug), headers: @headers, as: :json

    assert_response :success
    user_levels = @current_user.user_levels.joins(:level).where(levels: { course: @course })
    assert_json_response({
      user_levels: SerializeUserLevels.(user_levels)
    })
  end

  test "GET index returns empty array when no user_levels exist for course" do
    get internal_user_levels_path(course_slug: @course.slug), headers: @headers, as: :json

    assert_response :success
    assert_json_response({ user_levels: [] })
  end

  test "GET index only returns current user's user_levels for the course" do
    other_user = create(:user)
    level1 = create(:level, course: @course, slug: "my-level")
    level2 = create(:level, course: @course, slug: "other-level")

    lesson1 = create(:lesson, :exercise, level: level1, slug: "my-lesson")
    lesson2 = create(:lesson, :exercise, level: level2, slug: "other-lesson")

    create(:user_course, user: @current_user, course: @course)
    create(:user_level, user: @current_user, level: level1)
    create(:user_level, user: other_user, level: level2)

    create(:user_lesson, user: @current_user, lesson: lesson1)
    create(:user_lesson, user: other_user, lesson: lesson2)

    get internal_user_levels_path(course_slug: @course.slug), headers: @headers, as: :json

    assert_response :success
    user_levels = @current_user.user_levels.joins(:level).where(levels: { course: @course })
    assert_json_response({
      user_levels: SerializeUserLevels.(user_levels)
    })
  end

  test "GET index returns correct JSON structure" do
    level = create(:level, course: @course)
    lesson = create(:lesson, :exercise, level: level)
    create(:user_course, user: @current_user, course: @course)
    create(:user_level, user: @current_user, level: level)
    create(:user_lesson, user: @current_user, lesson: lesson)

    get internal_user_levels_path(course_slug: @course.slug), headers: @headers, as: :json

    assert_response :success

    assert_json_structure({
      user_levels: [
        {
          level_slug: String,
          user_lessons: [
            {
              lesson_slug: String,
              status: String
            }
          ]
        }
      ]
    })
  end

  test "GET index uses SerializeUserLevels" do
    Prosopite.finish # Stop scan before creating test data
    create(:user_course, user: @current_user, course: @course)
    level1 = create(:level, course: @course)
    level2 = create(:level, course: @course)
    user_level1 = create(:user_level, user: @current_user, level: level1)
    user_level2 = create(:user_level, user: @current_user, level: level2)
    user_levels = [user_level1, user_level2]
    serialized_data = [{ level_slug: "test" }]

    SerializeUserLevels.expects(:call).with { |arg| arg.map(&:id).sort == user_levels.map(&:id).sort }.returns(serialized_data)

    Prosopite.scan # Resume scan for the actual request
    get internal_user_levels_path(course_slug: @course.slug), headers: @headers, as: :json

    assert_response :success
    assert_json_response({ user_levels: serialized_data })
  end

  test "GET index maintains level position order" do
    level1 = create(:level, course: @course, slug: "level-c", position: 3)
    level2 = create(:level, course: @course, slug: "level-a", position: 1)
    level3 = create(:level, course: @course, slug: "level-b", position: 2)

    lesson1 = create(:lesson, :exercise, level: level1, slug: "lesson-c")
    lesson2 = create(:lesson, :exercise, level: level2, slug: "lesson-a")
    lesson3 = create(:lesson, :exercise, level: level3, slug: "lesson-b")

    create(:user_course, user: @current_user, course: @course)
    create(:user_level, user: @current_user, level: level1)
    create(:user_level, user: @current_user, level: level2)
    create(:user_level, user: @current_user, level: level3)

    create(:user_lesson, user: @current_user, lesson: lesson1)
    create(:user_lesson, user: @current_user, lesson: lesson2)
    create(:user_lesson, user: @current_user, lesson: lesson3)

    get internal_user_levels_path(course_slug: @course.slug), headers: @headers, as: :json

    assert_response :success
    user_levels = @current_user.user_levels.joins(:level).where(levels: { course: @course })
    assert_json_response({
      user_levels: SerializeUserLevels.(user_levels)
    })
  end

  test "GET index only returns user_levels for the specified course" do
    other_course = create(:course, slug: "other-course")
    level1 = create(:level, course: @course, slug: "my-level")
    level2 = create(:level, course: other_course, slug: "other-level")

    lesson1 = create(:lesson, :exercise, level: level1)
    lesson2 = create(:lesson, :exercise, level: level2)

    create(:user_course, user: @current_user, course: @course)
    create(:user_course, user: @current_user, course: other_course)
    create(:user_level, user: @current_user, level: level1)
    create(:user_level, user: @current_user, level: level2)

    create(:user_lesson, user: @current_user, lesson: lesson1)
    create(:user_lesson, user: @current_user, lesson: lesson2)

    get internal_user_levels_path(course_slug: @course.slug), headers: @headers, as: :json

    assert_response :success
    assert_equal 1, response.parsed_body["user_levels"].length
    assert_equal level1.slug, response.parsed_body["user_levels"].first["level_slug"]
  end

  test "GET index returns 404 for non-existent course" do
    get internal_user_levels_path(course_slug: "non-existent"), headers: @headers, as: :json

    assert_response :not_found
  end

  # Error handler tests
  test "PATCH complete returns 422 when lessons are incomplete" do
    level = create(:level, course: @course, slug: "test-level")
    lesson1 = create(:lesson, :exercise, level:)
    create(:lesson, :exercise, level:) # lesson2 not completed
    create(:lesson, :exercise, level:) # lesson3 not completed
    create(:user_course, user: @current_user, course: @course)
    create(:user_level, user: @current_user, level:)
    create(:user_lesson, user: @current_user, lesson: lesson1, completed_at: Time.current)

    patch complete_internal_user_level_path(course_slug: @course.slug, level_slug: level.slug),
      headers: @headers,
      as: :json

    assert_response :unprocessable_entity
    assert_equal "Cannot complete level: 2 lesson(s) incomplete", response.parsed_body["error"]
  end

  test "PATCH complete emits lesson_unlocked event for first lesson of next level" do
    level1 = create(:level, course: @course, slug: "level-1", position: 1)
    level2 = create(:level, course: @course, slug: "level-2", position: 2)
    lesson1 = create(:lesson, :exercise, level: level1, slug: "level1-lesson", position: 1)
    create(:lesson, :exercise, level: level2, slug: "level2-first-lesson", position: 1)
    create(:user_course, user: @current_user, course: @course)
    create(:user_level, user: @current_user, level: level1)
    create(:user_lesson, user: @current_user, lesson: lesson1, completed_at: Time.current)

    patch complete_internal_user_level_path(course_slug: @course.slug, level_slug: level1.slug),
      headers: @headers,
      as: :json

    assert_response :success
    assert_json_response({
      meta: {
        events: [
          {
            type: "lesson_unlocked",
            data: {
              lesson_slug: "level2-first-lesson"
            }
          }
        ]
      }
    })
  end

  test "PATCH complete does not emit lesson_unlocked event when no next level exists" do
    level = create(:level, course: @course, slug: "last-level", position: 1)
    lesson = create(:lesson, :exercise, level:, slug: "last-lesson", position: 1)
    create(:user_course, user: @current_user, course: @course)
    create(:user_level, user: @current_user, level:)
    create(:user_lesson, user: @current_user, lesson:, completed_at: Time.current)

    patch complete_internal_user_level_path(course_slug: @course.slug, level_slug: level.slug),
      headers: @headers,
      as: :json

    assert_response :success
    assert_json_response({
      meta: {
        events: []
      }
    })
  end
end
