require "test_helper"

class SerializeAdminLessonTest < ActiveSupport::TestCase
  test "serializes lesson with all attributes" do
    lesson = create(:lesson, :video, slug: "hello-world", position: 1,
      data: { sources: [{ id: "abc123" }] })

    expected = {
      id: lesson.id,
      slug: "hello-world",
      type: "video",
      position: 1,
      data: { sources: [{ id: "abc123" }] },
      walkthrough_video_data: nil
    }

    assert_equal expected, SerializeAdminLesson.(lesson)
  end

  # Lesson copy is authored in the front-end curriculum repo.
  test "does not include title or description" do
    result = SerializeAdminLesson.(create(:lesson, :exercise))

    refute result.key?(:title)
    refute result.key?(:description)
  end

  test "serializes data with symbol keys" do
    lesson = create(:lesson, :video, data: { sources: [{ id: "abc" }], foo: "bar" })

    result = SerializeAdminLesson.(lesson)

    assert_kind_of Hash, result[:data]
    assert result[:data].key?(:foo)
  end
end
