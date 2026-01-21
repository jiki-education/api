require "test_helper"

class Badge::TranslationTest < ActiveSupport::TestCase
  test "valid factory" do
    assert build(:badge_translation).valid?
  end

  test "validates presence of locale" do
    translation = build(:badge_translation, locale: nil)

    refute translation.valid?
    assert_includes translation.errors[:locale], "can't be blank"
  end

  test "validates presence of name" do
    translation = build(:badge_translation, name: nil)

    refute translation.valid?
    assert_includes translation.errors[:name], "can't be blank"
  end

  test "validates presence of description" do
    translation = build(:badge_translation, description: nil)

    refute translation.valid?
    assert_includes translation.errors[:description], "can't be blank"
  end

  test "validates presence of fun_fact" do
    translation = build(:badge_translation, fun_fact: nil)

    refute translation.valid?
    assert_includes translation.errors[:fun_fact], "can't be blank"
  end

  test "validates uniqueness of locale scoped to badge_id" do
    badge = create(:member_badge)
    create(:badge_translation, badge:, locale: "hu")
    duplicate = build(:badge_translation, badge:, locale: "hu")

    refute duplicate.valid?
    assert_includes duplicate.errors[:locale], "has already been taken"
  end

  test "allows same locale for different badges" do
    badge1 = create(:member_badge)
    badge2 = create(:maze_navigator_badge)
    create(:badge_translation, badge: badge1, locale: "hu")
    duplicate = build(:badge_translation, badge: badge2, locale: "hu")

    assert duplicate.valid?
  end

  test "rejects English locale" do
    translation = build(:badge_translation, locale: "en")

    refute translation.valid?
    assert_includes translation.errors[:locale], "English content belongs on Badge model"
  end

  test "validates only supported locales" do
    translation = build(:badge_translation, locale: "unsupported")

    refute translation.valid?
    assert_includes translation.errors[:locale], "is not a supported locale"
  end

  test "accepts supported locales" do
    %w[hu fr].each do |locale|
      translation = build(:badge_translation, locale:)
      assert translation.valid?, "Expected #{locale} to be valid"
    end
  end

  test ".find_for returns translation for badge and locale" do
    badge = create(:member_badge)
    translation = create(:badge_translation, badge:, locale: "hu")

    result = Badge::Translation.find_for(badge, "hu")

    assert_equal translation, result
  end

  test ".find_for returns nil when translation doesn't exist" do
    badge = create(:member_badge)

    result = Badge::Translation.find_for(badge, "fr")

    assert_nil result
  end

  test ".find_for returns nil for English locale" do
    badge = create(:member_badge)

    result = Badge::Translation.find_for(badge, "en")

    assert_nil result
  end

  test "belongs to badge" do
    badge = create(:member_badge)
    translation = create(:badge_translation, badge:)

    assert_equal badge, translation.badge
  end
end
