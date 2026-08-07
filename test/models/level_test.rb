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

  # Only email copy is translated here - everything a screen renders is
  # authored in the front-end curriculum repo.
  test "#content_for_locale returns English email copy from main model" do
    level = create(:level,
      milestone_email_subject: "Nice one!",
      milestone_email_content_markdown: "You finished it.")

    content = level.content_for_locale("en")

    assert_equal "Nice one!", content[:milestone_email_subject]
    assert_equal "You finished it.", content[:milestone_email_content_markdown]
  end

  test "#content_for_locale returns translated email copy when available" do
    level = create(:level)
    create(:level_translation,
      level:,
      locale: "hu",
      milestone_email_subject: "Gratulálunk!",
      milestone_email_content_markdown: "Befejezted az összes leckét.")

    content = level.content_for_locale("hu")

    assert_equal "Gratulálunk!", content[:milestone_email_subject]
    assert_equal "Befejezted az összes leckét.", content[:milestone_email_content_markdown]
  end

  test "#content_for_locale falls back to English when translation missing" do
    level = create(:level,
      milestone_email_subject: "Nice one!",
      milestone_email_content_markdown: "You finished it.")

    content = level.content_for_locale("fr")

    assert_equal "Nice one!", content[:milestone_email_subject]
    assert_equal "You finished it.", content[:milestone_email_content_markdown]
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
    translation2 = create(:level_translation, level:, locale: "es-ES")

    assert_equal [translation1, translation2], level.translations.order(:id).to_a
  end

  test "destroys translations when level is destroyed" do
    level = create(:level)
    translation = create(:level_translation, level:)

    level.destroy

    refute Level::Translation.exists?(translation.id)
  end
end
