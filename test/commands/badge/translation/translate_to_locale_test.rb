require "test_helper"

class Badge::Translation::TranslateToLocaleTest < ActiveSupport::TestCase
  test "creates translated badge with correct attributes" do
    badge = create(:member_badge)

    translation = {
      email_subject: "Új jelvényt szereztél!",
      email_content_markdown: "Gratulálunk!"
    }
    Gemini::Translate.stubs(:call).returns(translation)

    target = Badge::Translation::TranslateToLocale.(badge, "hu")

    assert target.persisted?
    assert_equal badge.id, target.badge_id
    assert_equal "hu", target.locale
    assert_equal "Új jelvényt szereztél!", target.email_subject
    assert_equal "Gratulálunk!", target.email_content_markdown
  end

  test "calls Gemini::Translate with correct parameters" do
    badge = create(:member_badge)

    translation = { email_subject: "Test", email_content_markdown: "Test" }

    Gemini::Translate.expects(:call).with(
      instance_of(String), # The full prompt
      instance_of(Hash), # schema
      model: :flash
    ).returns(translation)

    assert Badge::Translation::TranslateToLocale.(badge, "hu").persisted?
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
    existing = create(:badge_translation, badge:, locale: "hu", email_subject: "Old Subject")

    translation = { email_subject: "New Subject", email_content_markdown: "New Content" }
    Gemini::Translate.stubs(:call).returns(translation)

    target = Badge::Translation::TranslateToLocale.(badge, "hu")

    refute Badge::Translation.exists?(existing.id)
    assert target.persisted?
    assert_equal "New Subject", target.email_subject
  end

  test "translation prompt includes badge context" do
    badge = create(:member_badge)

    command = Badge::Translation::TranslateToLocale.new(badge, "hu")
    prompt = command.send(:translation_prompt)

    assert_includes prompt, "Badge: #{badge.slug}"
    assert_includes prompt, "Target Language: Hungarian (hu)"
  end

  test "translation prompt includes both source fields" do
    badge = create(:member_badge, email_subject: "Unique subject", email_content_markdown: "Unique content")

    command = Badge::Translation::TranslateToLocale.new(badge, "hu")
    prompt = command.send(:translation_prompt)

    assert_includes prompt, "Unique subject"
    assert_includes prompt, "Unique content"
  end

  # The email copy names the badge, and nothing interpolates that name, so the
  # translator has to inflect it for the target language itself.
  test "translation prompt tells the model to inflect the badge name" do
    command = Badge::Translation::TranslateToLocale.new(create(:member_badge), "hu")

    assert_includes command.send(:translation_prompt), "Inflect that"
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
