require "test_helper"

class Internal::LevelsControllerTest < ApplicationControllerTest
  setup do
    setup_user
    @course = create(:course, slug: "test-course")
  end

  # Authentication guards
  guard_incorrect_token! :internal_levels_path, args: [{ course_slug: "test-course" }], method: :get do
    create(:course, slug: "test-course")
  end

  test "GET index returns all levels with nested lessons for a course" do
    level1 = create(:level, course: @course, slug: "level-1")
    level2 = create(:level, course: @course, slug: "level-2")
    create(:lesson, :exercise, level: level1, slug: "lesson-1")
    create(:lesson, :video, level: level1, slug: "lesson-2")
    create(:lesson, :exercise, level: level2, slug: "lesson-3")

    get internal_levels_path(course_slug: @course.slug), as: :json

    assert_response :success
    assert_json_response({
      levels: SerializeLevels.([level1, level2])
    })
  end

  test "GET index returns empty array when no levels exist for course" do
    get internal_levels_path(course_slug: @course.slug), as: :json

    assert_response :success
    assert_json_response({ levels: [] })
  end

  test "GET index returns correct JSON structure" do
    level = create(:level, course: @course)
    create(:lesson, :exercise, level: level)

    get internal_levels_path(course_slug: @course.slug), as: :json

    assert_response :success

    assert_json_structure({
      levels: [
        {
          slug: String,
          lessons: [
            {
              slug: String,
              type: String
            }
          ]
        }
      ]
    })
  end

  test "GET index uses SerializeLevels" do
    Prosopite.finish # Stop scan before creating test data
    levels = create_list(:level, 2, course: @course)
    serialized_data = [{ slug: "test" }]

    SerializeLevels.expects(:call).with { |arg| arg.to_a == levels }.returns(serialized_data)

    Prosopite.scan # Resume scan for the actual request
    get internal_levels_path(course_slug: @course.slug), as: :json

    assert_response :success
    assert_json_response({ levels: serialized_data })
  end

  test "GET index only returns levels for the specified course" do
    other_course = create(:course, slug: "other-course")
    level1 = create(:level, course: @course, slug: "my-level")
    create(:level, course: other_course, slug: "other-level")

    get internal_levels_path(course_slug: @course.slug), as: :json

    assert_response :success
    assert_equal 1, response.parsed_body["levels"].length
    assert_equal level1.slug, response.parsed_body["levels"].first["slug"]
  end

  test "GET index returns 404 for non-existent course" do
    get internal_levels_path(course_slug: "non-existent"), as: :json

    assert_response :not_found
  end
end
