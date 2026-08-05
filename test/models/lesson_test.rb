require "test_helper"

class LessonTest < ActiveSupport::TestCase
  test "valid factory" do
    assert build(:lesson, :exercise).valid?
  end

  test "auto-increments position within level" do
    level = create(:level)
    lesson1 = create(:lesson, :exercise, level:)
    lesson2 = create(:lesson, :exercise, level:)

    assert_equal 1, lesson1.position
    assert_equal 2, lesson2.position
  end

  test "requires unique slug" do
    create(:lesson, :exercise, slug: "first-function")
    duplicate = build(:lesson, :exercise, slug: "first-function")

    refute duplicate.valid?
  end

  test "position unique within level" do
    level1 = create(:level)
    level2 = create(:level)

    lesson1 = create(:lesson, :exercise, level: level1, position: 1)
    lesson2 = create(:lesson, :exercise, level: level2, position: 1) # Should be valid - different level

    assert lesson1.valid?
    assert lesson2.valid?
    assert_equal 1, lesson1.position
    assert_equal 1, lesson2.position
  end

  test "to_param returns slug" do
    lesson = create(:lesson, :exercise, slug: "hello-world")

    assert_equal "hello-world", lesson.to_param
  end

  # Data validation tests
  #
  # Exercise lessons carry no data - the lesson slug alone identifies the
  # front-end curriculum exercise.
  test "exercise lesson is valid with no data" do
    lesson = build(:lesson, type: 'exercise')

    assert lesson.valid?
    assert_empty lesson.data
  end

  test "video lesson requires sources in data" do
    lesson = build(:lesson, type: 'video', data: { other_key: 'value' })

    refute lesson.valid?
    assert_includes lesson.errors[:data], 'must contain sources for video lessons'
  end

  test "video lesson is valid with sources in data" do
    lesson = build(:lesson, type: 'video', data: { sources: [{ id: 'abc123' }] })

    assert lesson.valid?
  end

  test "choose_language lesson requires sources in data" do
    lesson = build(:lesson, type: 'choose_language', data: { other_key: 'value' })

    refute lesson.valid?
    assert_includes lesson.errors[:data], 'must contain sources for choose_language lessons'
  end
end
