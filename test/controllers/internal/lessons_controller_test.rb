require "test_helper"

class Internal::LessonsControllerTest < ApplicationControllerTest
  setup do
    setup_user
  end

  # Authentication guards
  guard_incorrect_token! :internal_lesson_path, args: ["test-lesson"], method: :get

  test "GET show returns lesson with data" do
    level = create(:level)
    lesson = create(:lesson, :exercise, level: level, slug: "test-lesson", data: { slug: "ex1", title: "Test Exercise" })

    get internal_lesson_path(lesson_slug: "test-lesson"), headers: @headers, as: :json

    assert_response :success
    assert_json_response({
      lesson: SerializeLesson.(lesson, include_data: true)
    })
  end

  test "GET show returns 404 for non-existent lesson" do
    get internal_lesson_path(lesson_slug: "non-existent"), headers: @headers, as: :json

    assert_response :not_found
  end

  test "GET show uses SerializeLesson" do
    Prosopite.finish # Stop scan before creating test data
    level = create(:level)
    lesson = create(:lesson, :exercise, level: level, slug: "test-lesson")
    serialized_data = { slug: "test", type: "exercise", data: {} }

    SerializeLesson.expects(:call).with(lesson, include_data: true, language: nil).returns(serialized_data)

    Prosopite.scan # Resume scan for the actual request
    get internal_lesson_path(lesson_slug: "test-lesson"), headers: @headers, as: :json

    assert_response :success
    assert_json_response({ lesson: serialized_data })
  end
end
