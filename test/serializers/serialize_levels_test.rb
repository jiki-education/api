require "test_helper"

class SerializeLevelsTest < ActiveSupport::TestCase
  test "serializes multiple levels with lessons" do
    level1 = create(:level, slug: "level-1", milestone_summary: "Summary 1")
    level2 = create(:level, slug: "level-2", milestone_summary: "Summary 2")
    create(:lesson, level: level1, slug: "l1", type: "exercise", data: { slug: "ex1" })
    create(:lesson, level: level2, slug: "l2", type: "tutorial", data: { slug: "ex2" })

    expected = [
      {
        slug: "level-1",
        milestone_summary: "Summary 1",
        lessons: [
          { slug: "l1", type: "exercise" }
        ]
      },
      {
        slug: "level-2",
        milestone_summary: "Summary 2",
        lessons: [
          { slug: "l2", type: "tutorial" }
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
    create(:lesson, level: level, slug: "lesson-solo", type: "exercise", data: { slug: "test" })

    expected = [
      {
        slug: "solo",
        milestone_summary: "Solo summary",
        lessons: [
          { slug: "lesson-solo", type: "exercise" }
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
end
