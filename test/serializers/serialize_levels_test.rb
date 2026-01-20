require "test_helper"

class SerializeLevelsTest < ActiveSupport::TestCase
  test "serializes multiple levels with lessons including title and description but not data" do
    level1 = create(:level, slug: "level-1", milestone_summary: "Summary 1")
    level2 = create(:level, slug: "level-2", milestone_summary: "Summary 2")
    create(:lesson, :exercise, level: level1, slug: "l1", title: "Lesson 1", description: "Desc 1", data: { slug: "ex1" })
    create(:lesson, :video, level: level2, slug: "l2", title: "Lesson 2", description: "Desc 2")

    expected = [
      {
        slug: "level-1",
        milestone_summary: "Summary 1",
        lessons: [
          { slug: "l1", title: "Lesson 1", description: "Desc 1", type: "exercise" }
        ]
      },
      {
        slug: "level-2",
        milestone_summary: "Summary 2",
        lessons: [
          { slug: "l2", title: "Lesson 2", description: "Desc 2", type: "video" }
        ]
      }
    ]

    assert_equal(expected, SerializeLevels.([level1, level2]))
  end

  test "returns empty array for no levels" do
    assert_empty SerializeLevels.([])
  end

  test "serializes single level" do
    level = create(:level, slug: "solo", milestone_summary: "Solo summary")
    create(:lesson, :exercise, level: level, slug: "lesson-solo", title: "Solo Lesson", description: "Solo desc", data: { slug: "test" })

    expected = [
      {
        slug: "solo",
        milestone_summary: "Solo summary",
        lessons: [
          { slug: "lesson-solo", title: "Solo Lesson", description: "Solo desc", type: "exercise" }
        ]
      }
    ]
    assert_equal(expected, SerializeLevels.([level]))
  end

  test "uses translated milestone_summary for non-English locale" do
    level1 = create(:level, slug: "level-1", milestone_summary: "English summary 1")
    level2 = create(:level, slug: "level-2", milestone_summary: "English summary 2")
    create(:level_translation, level: level1, locale: "hu", milestone_summary: "Magyar összefoglaló 1")
    create(:level_translation, level: level2, locale: "hu", milestone_summary: "Magyar összefoglaló 2")

    I18n.with_locale(:hu) do
      result = SerializeLevels.([level1, level2])
      assert_equal "Magyar összefoglaló 1", result[0][:milestone_summary]
      assert_equal "Magyar összefoglaló 2", result[1][:milestone_summary]
    end
  end

  test "lessons include translated title and description for non-English locale" do
    level = create(:level, slug: "level-1", milestone_summary: "Summary")
    lesson = create(:lesson, :exercise, level: level, slug: "l1", title: "English Title", description: "English desc", data: { slug: "ex1" })
    create(:lesson_translation, lesson: lesson, locale: "hu", title: "Magyar cím", description: "Magyar leírás")

    I18n.with_locale(:hu) do
      result = SerializeLevels.([level])
      assert_equal "Magyar cím", result[0][:lessons][0][:title]
      assert_equal "Magyar leírás", result[0][:lessons][0][:description]
    end
  end

  test "lessons fall back to English for missing translations" do
    level = create(:level, slug: "level-1", milestone_summary: "Summary")
    lesson1 = create(:lesson, :exercise, level: level, slug: "l1", title: "Translated Title", description: "Translated desc", data: { slug: "ex1" })
    create(:lesson, :video, level: level, slug: "l2", title: "English Only", description: "No translation")
    create(:lesson_translation, lesson: lesson1, locale: "hu", title: "Magyar cím", description: "Magyar leírás")
    # No translation for lesson2

    I18n.with_locale(:hu) do
      result = SerializeLevels.([level])
      # lesson1 should use Hungarian translation
      assert_equal "Magyar cím", result[0][:lessons][0][:title]
      assert_equal "Magyar leírás", result[0][:lessons][0][:description]
      # lesson2 should fall back to English
      assert_equal "English Only", result[0][:lessons][1][:title]
      assert_equal "No translation", result[0][:lessons][1][:description]
    end
  end
end
