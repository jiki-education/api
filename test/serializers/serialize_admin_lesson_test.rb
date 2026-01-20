require "test_helper"

class SerializeAdminLessonTest < ActiveSupport::TestCase
  test "serializes lesson with all attributes" do
    lesson = create(:lesson, :exercise,
      slug: "hello-world",
      title: "Hello World",
      description: "Your first lesson",
      position: 1,
      data: { slug: "some-exercise", key: "value" })

    expected = {
      id: lesson.id,
      slug: "hello-world",
      title: "Hello World",
      description: "Your first lesson",
      type: "exercise",
      position: 1,
      data: { slug: "some-exercise", key: "value" }
    }

    assert_equal expected, SerializeAdminLesson.(lesson)
  end

  test "includes all required fields" do
    lesson = create(:lesson, :exercise)

    result = SerializeAdminLesson.(lesson)

    assert result.key?(:id)
    assert result.key?(:slug)
    assert result.key?(:title)
    assert result.key?(:description)
    assert result.key?(:type)
    assert result.key?(:position)
    assert result.key?(:data)
  end

  test "serializes data with string keys" do
    lesson = create(:lesson, :exercise, data: { slug: "test", foo: "bar" })

    result = SerializeAdminLesson.(lesson)

    assert_kind_of Hash, result[:data]
    assert result[:data].key?(:foo)
  end
end
