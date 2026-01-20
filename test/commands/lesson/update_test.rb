require "test_helper"

class Lesson::UpdateTest < ActiveSupport::TestCase
  test "updates lesson attributes" do
    lesson = create :lesson, :exercise, title: "Old Title", description: "Old description"

    updated_lesson = Lesson::Update.(lesson, { title: "New Title", description: "New description" })

    assert_equal "New Title", updated_lesson.title
    assert_equal "New description", updated_lesson.description
    assert_equal lesson.id, updated_lesson.id
  end

  test "updates position" do
    lesson = create :lesson, :exercise, position: 1

    updated_lesson = Lesson::Update.(lesson, { position: 5 })

    assert_equal 5, updated_lesson.position
  end

  test "updates type" do
    lesson = create :lesson, :exercise

    updated_lesson = Lesson::Update.(lesson, { type: "video", data: { sources: [{ id: "abc123" }] } })

    assert_equal "video", updated_lesson.type
  end

  test "updates data" do
    lesson = create :lesson, :exercise, data: { slug: "test", key: "old_value" }

    updated_lesson = Lesson::Update.(lesson, { data: { slug: "test", key: "new_value", foo: "bar" } })

    assert_equal({ slug: "test", key: "new_value", foo: "bar" }, updated_lesson.data)
  end

  test "raises error on invalid attributes" do
    lesson = create :lesson, :exercise

    assert_raises ActiveRecord::RecordInvalid do
      Lesson::Update.(lesson, { title: "" })
    end
  end

  test "returns updated lesson" do
    lesson = create :lesson, :exercise

    result = Lesson::Update.(lesson, { title: "Updated" })

    assert_instance_of Lesson, result
    assert_equal lesson.id, result.id
  end
end
