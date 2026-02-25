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

  # Translation-related tests
  test "has many translations" do
    lesson = create(:lesson, :exercise)
    translation1 = create(:lesson_translation, lesson:, locale: "hu")
    translation2 = create(:lesson_translation, lesson:, locale: "fr")

    assert_includes lesson.translations, translation1
    assert_includes lesson.translations, translation2
    assert_equal 2, lesson.translations.count
  end

  test "destroys translations when lesson is destroyed" do
    lesson = create(:lesson, :exercise)
    translation = create(:lesson_translation, lesson:)

    assert_difference -> { Lesson::Translation.count }, -1 do
      lesson.destroy
    end

    refute Lesson::Translation.exists?(translation.id)
  end

  test "content_for_locale returns English content for 'en' locale" do
    lesson = create(:lesson, :exercise, title: "English Title", description: "English Description")
    create(:lesson_translation, lesson:, locale: "hu", title: "Magyar cím", description: "Magyar leírás")

    content = lesson.content_for_locale("en")

    assert_equal "English Title", content[:title]
    assert_equal "English Description", content[:description]
  end

  test "content_for_locale returns translated content for non-English locale" do
    lesson = create(:lesson, :exercise, title: "English Title", description: "English Description")
    create(:lesson_translation, lesson:, locale: "hu", title: "Magyar cím", description: "Magyar leírás")

    content = lesson.content_for_locale("hu")

    assert_equal "Magyar cím", content[:title]
    assert_equal "Magyar leírás", content[:description]
  end

  test "content_for_locale falls back to English when translation doesn't exist" do
    lesson = create(:lesson, :exercise, title: "English Title", description: "English Description")

    content = lesson.content_for_locale("fr")

    assert_equal "English Title", content[:title]
    assert_equal "English Description", content[:description]
  end

  test "translation_for returns nil for English locale" do
    lesson = create(:lesson, :exercise)

    assert_nil lesson.translation_for("en")
  end

  test "translation_for returns translation record for non-English locale" do
    lesson = create(:lesson, :exercise)
    translation = create(:lesson_translation, lesson:, locale: "hu")

    result = lesson.translation_for("hu")

    assert_equal translation, result
  end

  test "translation_for returns nil when translation doesn't exist" do
    lesson = create(:lesson, :exercise)

    assert_nil lesson.translation_for("fr")
  end

  # Data validation tests
  test "exercise lesson requires slug in data" do
    lesson = build(:lesson, type: 'exercise', data: { other_key: 'value' })

    refute lesson.valid?
    assert_includes lesson.errors[:data], 'must contain slug for exercise lessons'
  end

  test "exercise lesson is valid with slug in data" do
    lesson = build(:lesson, type: 'exercise', data: { slug: 'my-exercise' })

    assert lesson.valid?
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
end
