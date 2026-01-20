require "test_helper"

class Lesson::TranslationTest < ActiveSupport::TestCase
  test "valid factory" do
    assert build(:lesson_translation).valid?
  end

  test "validates presence of locale" do
    translation = build(:lesson_translation, locale: nil)

    refute translation.valid?
    assert_includes translation.errors[:locale], "can't be blank"
  end

  test "validates presence of title" do
    translation = build(:lesson_translation, title: nil)

    refute translation.valid?
    assert_includes translation.errors[:title], "can't be blank"
  end

  test "validates presence of description" do
    translation = build(:lesson_translation, description: nil)

    refute translation.valid?
    assert_includes translation.errors[:description], "can't be blank"
  end

  test "validates uniqueness of locale scoped to lesson_id" do
    lesson = create(:lesson, :exercise)
    create(:lesson_translation, lesson:, locale: "hu")
    duplicate = build(:lesson_translation, lesson:, locale: "hu")

    refute duplicate.valid?
    assert_includes duplicate.errors[:locale], "has already been taken"
  end

  test "allows same locale for different lessons" do
    lesson1 = create(:lesson, :exercise)
    lesson2 = create(:lesson, :exercise)
    create(:lesson_translation, lesson: lesson1, locale: "hu")
    duplicate = build(:lesson_translation, lesson: lesson2, locale: "hu")

    assert duplicate.valid?
  end

  test "rejects English locale" do
    translation = build(:lesson_translation, locale: "en")

    refute translation.valid?
    assert_includes translation.errors[:locale], "English content belongs on Lesson model"
  end

  test "validates only supported locales" do
    translation = build(:lesson_translation, locale: "unsupported")

    refute translation.valid?
    assert_includes translation.errors[:locale], "is not a supported locale"
  end

  test "accepts supported locales" do
    %w[hu fr].each do |locale|
      translation = build(:lesson_translation, locale:)
      assert translation.valid?, "Expected #{locale} to be valid"
    end
  end

  test ".find_for returns translation for lesson and locale" do
    lesson = create(:lesson, :exercise)
    translation = create(:lesson_translation, lesson:, locale: "hu")

    result = Lesson::Translation.find_for(lesson, "hu")

    assert_equal translation, result
  end

  test ".find_for returns nil when translation doesn't exist" do
    lesson = create(:lesson, :exercise)

    result = Lesson::Translation.find_for(lesson, "fr")

    assert_nil result
  end

  test ".find_for returns nil for English locale" do
    lesson = create(:lesson, :exercise)

    result = Lesson::Translation.find_for(lesson, "en")

    assert_nil result
  end

  test "belongs to lesson" do
    lesson = create(:lesson, :exercise)
    translation = create(:lesson_translation, lesson:)

    assert_equal lesson, translation.lesson
  end
end
