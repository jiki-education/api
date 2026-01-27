require "test_helper"

class LevelTest < ActiveSupport::TestCase
  test "valid factory" do
    assert build(:level).valid?
  end

  test "auto-increments position within course" do
    course = create(:course)
    level1 = create(:level, course:)
    level2 = create(:level, course:)

    assert_equal 1, level1.position
    assert_equal 2, level2.position
  end

  test "requires unique slug" do
    create(:level, slug: "fundamentals")
    duplicate = build(:level, slug: "fundamentals")

    refute duplicate.valid?
  end

  test "validates presence of milestone_summary" do
    level = build(:level, milestone_summary: nil)

    refute level.valid?
    assert_includes level.errors[:milestone_summary], "can't be blank"
  end

  test "validates presence of milestone_content" do
    level = build(:level, milestone_content: nil)

    refute level.valid?
    assert_includes level.errors[:milestone_content], "can't be blank"
  end

  test "#content_for_locale returns English content from main model" do
    level = create(:level,
      title: "Ruby Basics",
      description: "Learn Ruby",
      milestone_summary: "Great!",
      milestone_content: "# Done!")

    content = level.content_for_locale("en")

    assert_equal "Ruby Basics", content[:title]
    assert_equal "Learn Ruby", content[:description]
    assert_equal "Great!", content[:milestone_summary]
    assert_equal "# Done!", content[:milestone_content]
  end

  test "#content_for_locale returns translated content when available" do
    level = create(:level,
      title: "Ruby Basics",
      description: "Learn Ruby",
      milestone_summary: "Great!",
      milestone_content: "# Done!")

    create(:level_translation,
      level:,
      locale: "hu",
      title: "Ruby Alapok",
      description: "Tanuld meg",
      milestone_summary: "Szuper!",
      milestone_content: "# Kész!")

    content = level.content_for_locale("hu")

    assert_equal "Ruby Alapok", content[:title]
    assert_equal "Tanuld meg", content[:description]
    assert_equal "Szuper!", content[:milestone_summary]
    assert_equal "# Kész!", content[:milestone_content]
  end

  test "#content_for_locale falls back to English when translation missing" do
    level = create(:level,
      title: "Ruby Basics",
      description: "Learn Ruby",
      milestone_summary: "Great!",
      milestone_content: "# Done!")

    content = level.content_for_locale("fr")

    assert_equal "Ruby Basics", content[:title]
    assert_equal "Learn Ruby", content[:description]
    assert_equal "Great!", content[:milestone_summary]
    assert_equal "# Done!", content[:milestone_content]
  end

  test "#translation_for returns nil for English" do
    level = create(:level)

    assert_nil level.translation_for("en")
  end

  test "#translation_for returns translation record for non-English locale" do
    level = create(:level)
    translation = create(:level_translation, level:, locale: "hu")

    assert_equal translation, level.translation_for("hu")
  end

  test "#translation_for returns nil when translation doesn't exist" do
    level = create(:level)

    assert_nil level.translation_for("fr")
  end

  test "has many translations" do
    level = create(:level)
    translation1 = create(:level_translation, level:, locale: "hu")
    translation2 = create(:level_translation, level:, locale: "fr")

    assert_equal [translation1, translation2], level.translations.order(:id).to_a
  end

  test "destroys translations when level is destroyed" do
    level = create(:level)
    translation = create(:level_translation, level:)

    level.destroy

    refute Level::Translation.exists?(translation.id)
  end
end
