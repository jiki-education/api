require "test_helper"

class Badge::Translation::TranslateToLocaleTest < ActiveSupport::TestCase
  test "creates translated badge with correct attributes" do
    badge = create(:member_badge)

    translation = {
      name: "Tag",
      description: "Csatlakozott a Jikihez",
      fun_fact: "Üdvözöljük a közösségben!"
    }
    Gemini::Translate.stubs(:call).returns(translation)

    target = Badge::Translation::TranslateToLocale.(badge, "hu")

    assert target.persisted?
    assert_equal badge.id, target.badge_id
    assert_equal "hu", target.locale
    assert_equal "Tag", target.name
    assert_equal "Csatlakozott a Jikihez", target.description
    assert_equal "Üdvözöljük a közösségben!", target.fun_fact
  end

  test "calls Gemini::Translate with correct parameters" do
    badge = create(:member_badge)

    translation = {
      name: "Test",
      description: "Test",
      fun_fact: "Test"
    }

    Gemini::Translate.expects(:call).with(
      instance_of(String),
      instance_of(Hash),
      model: :flash
    ).returns(translation)

    result = Badge::Translation::TranslateToLocale.(badge, "hu")

    assert result.persisted?
  end

  test "raises error if target locale is English" do
    badge = create(:member_badge)

    error = assert_raises ArgumentError do
      Badge::Translation::TranslateToLocale.(badge, "en")
    end

    assert_equal "Target locale cannot be English (en)", error.message
  end

  test "raises error if target locale is not supported" do
    badge = create(:member_badge)

    error = assert_raises ArgumentError do
      Badge::Translation::TranslateToLocale.(badge, "unsupported")
    end

    assert_equal "Target locale not supported", error.message
  end

  test "deletes existing translation before creating new one (upsert)" do
    badge = create(:member_badge)
    existing = create(:badge_translation,
      badge:,
      locale: "hu",
      name: "Old Name",
      description: "Old Description",
      fun_fact: "Old Fun Fact")

    translation = {
      name: "New Name",
      description: "New Description",
      fun_fact: "New Fun Fact"
    }
    Gemini::Translate.stubs(:call).returns(translation)

    target = Badge::Translation::TranslateToLocale.(badge, "hu")

    refute Badge::Translation.exists?(existing.id)
    assert target.persisted?
    assert_equal "New Name", target.name
  end

  test "translation prompt includes badge context" do
    badge = create(:member_badge)

    translation = {
      name: "Test",
      description: "Test",
      fun_fact: "Test"
    }
    Gemini::Translate.stubs(:call).returns(translation)

    Badge::Translation::TranslateToLocale.(badge, "hu")

    command = Badge::Translation::TranslateToLocale.new(badge, "hu")
    prompt = command.send(:translation_prompt)

    assert_includes prompt, "Badge: #{badge.name} (#{badge.slug})"
    assert_includes prompt, "Target Language: Hungarian (hu)"
  end

  test "translation prompt includes all three source fields" do
    badge = create(:member_badge)

    command = Badge::Translation::TranslateToLocale.new(badge, "hu")
    prompt = command.send(:translation_prompt)

    assert_includes prompt, badge.name
    assert_includes prompt, badge.description
    assert_includes prompt, badge.fun_fact
  end

  test "translation prompt has localization expert instructions" do
    badge = create(:member_badge)

    command = Badge::Translation::TranslateToLocale.new(badge, "hu")
    prompt = command.send(:translation_prompt)

    assert_includes prompt, "professional localization expert"
    assert_includes prompt, "Return ONLY a valid JSON object"
  end

  test "raises Gemini::RateLimitError when rate limited" do
    badge = create(:member_badge)

    Gemini::Translate.stubs(:call).raises(Gemini::RateLimitError, "Rate limit exceeded")

    error = assert_raises Gemini::RateLimitError do
      Badge::Translation::TranslateToLocale.(badge, "hu")
    end

    assert_includes error.message, "Rate limit exceeded"
  end
end
