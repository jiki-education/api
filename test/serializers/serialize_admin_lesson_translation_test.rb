require "test_helper"

class SerializeAdminLessonTranslationTest < ActiveSupport::TestCase
  test "returns correct structure with all fields" do
    lesson = create(:lesson, :exercise, slug: "variables-intro")
    translation = create(:lesson_translation,
      lesson:,
      locale: "hu",
      title: "Magyar cím",
      description: "Magyar leírás")

    result = SerializeAdminLessonTranslation.(translation)

    assert_equal translation.id, result[:id]
    assert_equal "variables-intro", result[:lesson_slug]
    assert_equal "hu", result[:locale]
    assert_equal "Magyar cím", result[:title]
    assert_equal "Magyar leírás", result[:description]
  end

  test "includes lesson slug from association" do
    lesson = create(:lesson, :exercise, slug: "unique-slug")
    translation = create(:lesson_translation, lesson:)

    result = SerializeAdminLessonTranslation.(translation)

    assert_equal "unique-slug", result[:lesson_slug]
  end
end
