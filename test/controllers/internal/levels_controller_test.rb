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
    create(:lesson, :exercise, level: level1, slug: "lesson-1", data: { slug: :ex1 })
    create(:lesson, :video, level: level1, slug: "lesson-2")
    create(:lesson, :exercise, level: level2, slug: "lesson-3", data: { slug: :ex3 })

    get internal_levels_path(course_slug: @course.slug), headers: @headers, as: :json

    assert_response :success
    assert_json_response({
      levels: SerializeLevels.([level1, level2])
    })
  end

  test "GET index returns empty array when no levels exist for course" do
    get internal_levels_path(course_slug: @course.slug), headers: @headers, as: :json

    assert_response :success
    assert_json_response({ levels: [] })
  end

  test "GET index returns correct JSON structure" do
    level = create(:level, course: @course)
    create(:lesson, :exercise, level: level)

    get internal_levels_path(course_slug: @course.slug), headers: @headers, as: :json

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
    get internal_levels_path(course_slug: @course.slug), headers: @headers, as: :json

    assert_response :success
    assert_json_response({ levels: serialized_data })
  end

  test "GET index only returns levels for the specified course" do
    other_course = create(:course, slug: "other-course")
    level1 = create(:level, course: @course, slug: "my-level")
    create(:level, course: other_course, slug: "other-level")

    get internal_levels_path(course_slug: @course.slug), headers: @headers, as: :json

    assert_response :success
    assert_equal 1, response.parsed_body["levels"].length
    assert_equal level1.slug, response.parsed_body["levels"].first["slug"]
  end

  test "GET index returns 404 for non-existent course" do
    get internal_levels_path(course_slug: "non-existent"), headers: @headers, as: :json

    assert_response :not_found
  end

  # GET milestone tests

  guard_incorrect_token! :milestone_internal_level_path, args: [{ course_slug: "test-course", id: "ruby-basics" }], method: :get do
    course = create(:course, slug: "test-course")
    create(:level, course: course, slug: "ruby-basics")
  end

  test "GET milestone returns milestone for English (default locale)" do
    level = create(:level,
      course: @course,
      slug: "ruby-basics",
      title: "Ruby Basics",
      description: "Learn Ruby",
      milestone_summary: "Great!",
      milestone_content: "# Done!")

    get milestone_internal_level_path(course_slug: @course.slug, id: level.slug),
      headers: @headers,
      as: :json

    assert_response :success

    I18n.with_locale(:en) do
      assert_json_response({
        milestone: SerializeLevelMilestone.(level)
      })
    end
  end

  test "GET milestone returns milestone for specific locale via param" do
    level = create(:level,
      course: @course,
      slug: "ruby-basics",
      title: "Ruby Basics",
      description: "Learn Ruby",
      milestone_summary: "Great!",
      milestone_content: "# Done!")

    create(:level_translation,
      level:,
      locale: "hu",
      title: "Ruby Alapok",
      description: "Tanuld meg",
      milestone_summary: "Szuper!",
      milestone_content: "# Kész!")

    get milestone_internal_level_path(course_slug: @course.slug, id: level.slug, locale: "hu"),
      headers: @headers,
      as: :json

    assert_response :success

    I18n.with_locale(:hu) do
      assert_json_response({
        milestone: SerializeLevelMilestone.(level)
      })
    end
  end

  test "GET milestone falls back to English when translation missing" do
    level = create(:level,
      course: @course,
      slug: "ruby-basics",
      title: "Ruby Basics",
      description: "Learn Ruby",
      milestone_summary: "Great!",
      milestone_content: "# Done!")

    get milestone_internal_level_path(course_slug: @course.slug, id: level.slug, locale: "fr"),
      headers: @headers,
      as: :json

    assert_response :success

    json = response.parsed_body
    assert_equal "Ruby Basics", json["milestone"]["title"] # Fallback to English
  end

  test "GET milestone returns milestone for user's locale when no param provided" do
    @current_user.update!(locale: "hu")
    level = create(:level, course: @course)
    create(:level_translation, level:, locale: "hu", title: "Magyar cím")

    SerializeLevelMilestone.expects(:call).with(level).returns({ level_slug: "test" })

    get milestone_internal_level_path(course_slug: @course.slug, id: level.slug),
      headers: @headers,
      as: :json

    assert_response :success
    assert_equal "hu", I18n.locale.to_s
  end

  test "GET milestone returns 404 for non-existent level" do
    get milestone_internal_level_path(course_slug: @course.slug, id: "non-existent"),
      headers: @headers,
      as: :json

    assert_response :not_found
    assert_json_response({
      error: {
        type: "not_found",
        message: "Level not found"
      }
    })
  end

  test "GET milestone uses SerializeLevelMilestone" do
    level = create(:level, course: @course, slug: "ruby-basics")
    serialized_data = { level_slug: "ruby-basics" }

    SerializeLevelMilestone.expects(:call).with(level).returns(serialized_data)

    get milestone_internal_level_path(course_slug: @course.slug, id: level.slug),
      headers: @headers,
      as: :json

    assert_response :success
    assert_json_response({ milestone: serialized_data })
  end
end
