require "test_helper"

class Lesson::UpdateTest < ActiveSupport::TestCase
  test "updates lesson attributes" do
    lesson = create :lesson, :exercise

    updated_lesson = Lesson::Update.(lesson, { slug: "new-slug" })

    assert_equal "new-slug", updated_lesson.slug
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
    lesson = create :lesson, :video, data: { sources: [{ id: "old" }] }

    updated_lesson = Lesson::Update.(lesson, { data: { sources: [{ id: "new" }], foo: "bar" } })

    assert_equal({ sources: [{ id: "new" }], foo: "bar" }, updated_lesson.data)
  end

  test "raises error on invalid attributes" do
    lesson = create :lesson, :exercise

    assert_raises ActiveRecord::RecordInvalid do
      Lesson::Update.(lesson, { slug: "" })
    end
  end

  test "returns updated lesson" do
    lesson = create :lesson, :exercise

    result = Lesson::Update.(lesson, { slug: "updated" })

    assert_instance_of Lesson, result
    assert_equal lesson.id, result.id
  end
end
