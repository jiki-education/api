require "test_helper"

class Level::TranslationTest < ActiveSupport::TestCase
  test "valid factory" do
    assert build(:level_translation).valid?
  end

  test "validates presence of locale" do
    translation = build(:level_translation, locale: nil)

    refute translation.valid?
    assert_includes translation.errors[:locale], "can't be blank"
  end

  test "validates presence of milestone_email_subject" do
    translation = build(:level_translation, milestone_email_subject: nil)

    refute translation.valid?
    assert_includes translation.errors[:milestone_email_subject], "can't be blank"
  end

  test "validates presence of milestone_email_content_markdown" do
    translation = build(:level_translation, milestone_email_content_markdown: nil)

    refute translation.valid?
    assert_includes translation.errors[:milestone_email_content_markdown], "can't be blank"
  end

  test "validates uniqueness of locale scoped to level_id" do
    level = create(:level)
    create(:level_translation, level:, locale: "hu")
    duplicate = build(:level_translation, level:, locale: "hu")

    refute duplicate.valid?
    assert_includes duplicate.errors[:locale], "has already been taken"
  end

  test "allows same locale for different levels" do
    level1 = create(:level)
    level2 = create(:level)
    create(:level_translation, level: level1, locale: "hu")
    duplicate = build(:level_translation, level: level2, locale: "hu")

    assert duplicate.valid?
  end

  test "rejects English locale" do
    translation = build(:level_translation, locale: "en")

    refute translation.valid?
    assert_includes translation.errors[:locale], "English content belongs on Level model"
  end

  test "validates only supported locales" do
    translation = build(:level_translation, locale: "unsupported")

    refute translation.valid?
    assert_includes translation.errors[:locale], "is not a supported locale"
  end

  test "accepts supported locales" do
    I18n::WIP_LOCALES.each do |locale|
      translation = build(:level_translation, locale:)
      assert translation.valid?, "Expected #{locale} to be valid"
    end
  end

  test ".find_for returns translation for level and locale" do
    level = create(:level)
    translation = create(:level_translation, level:, locale: "hu")

    result = Level::Translation.find_for(level, "hu")

    assert_equal translation, result
  end

  test ".find_for returns nil when translation doesn't exist" do
    level = create(:level)

    result = Level::Translation.find_for(level, "fr")

    assert_nil result
  end

  test ".find_for returns nil for English locale" do
    level = create(:level)

    result = Level::Translation.find_for(level, "en")

    assert_nil result
  end

  test "belongs to level" do
    level = create(:level)
    translation = create(:level_translation, level:)

    assert_equal level, translation.level
  end
end
