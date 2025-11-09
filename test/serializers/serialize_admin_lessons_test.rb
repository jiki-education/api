require "test_helper"

class SerializeAdminLessonsTest < ActiveSupport::TestCase
  test "serializes multiple lessons" do
    lesson_1 = create(:lesson, slug: "lesson-1", title: "Lesson 1")
    lesson_2 = create(:lesson, slug: "lesson-2", title: "Lesson 2")

    expected = [
      {
        id: lesson_1.id,
        slug: "lesson-1",
        title: "Lesson 1",
        description: lesson_1.description,
        type: lesson_1.type,
        position: lesson_1.position,
        data: lesson_1.data
      },
      {
        id: lesson_2.id,
        slug: "lesson-2",
        title: "Lesson 2",
        description: lesson_2.description,
        type: lesson_2.type,
        position: lesson_2.position,
        data: lesson_2.data
      }
    ]

    assert_equal expected, SerializeAdminLessons.([lesson_1, lesson_2])
  end

  test "serializes empty array" do
    assert_empty SerializeAdminLessons.([])
  end

  test "calls SerializeAdminLesson for each lesson" do
    lesson_1 = create(:lesson, slug: "test-lesson-1-#{SecureRandom.hex(4)}")
    lesson_2 = create(:lesson, slug: "test-lesson-2-#{SecureRandom.hex(4)}")

    SerializeAdminLesson.expects(:call).with(lesson_1).returns({ id: lesson_1.id })
    SerializeAdminLesson.expects(:call).with(lesson_2).returns({ id: lesson_2.id })

    SerializeAdminLessons.([lesson_1, lesson_2])
  end
end
