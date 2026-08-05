require "test_helper"

class Level::Translation::TranslateToLocaleTest < ActiveSupport::TestCase
  test "creates translated level with correct attributes" do
    level = create(:level,
      slug: "ruby-basics",
      milestone_email_subject: "Congratulations!",
      milestone_email_content_markdown: "You did it!")

    translation = {
      milestone_email_subject: "Gratulálunk!",
      milestone_email_content_markdown: "Sikerült!"
    }
    Gemini::Translate.stubs(:call).returns(translation)

    target = Level::Translation::TranslateToLocale.(level, "hu")

    assert target.persisted?
    assert_equal level.id, target.level_id
    assert_equal "hu", target.locale
    assert_equal "Gratulálunk!", target.milestone_email_subject
    assert_equal "Sikerült!", target.milestone_email_content_markdown
  end

  test "calls Gemini::Translate with correct parameters" do
    level = create(:level, slug: "ruby-basics")

    translation = {
      milestone_email_subject: "Test",
      milestone_email_content_markdown: "Test"
    }

    # Verify Gemini::Translate is called with correct params
    Gemini::Translate.expects(:call).with(
      instance_of(String), # The full prompt
      instance_of(Hash), # schema
      model: :flash
    ).returns(translation)

    result = Level::Translation::TranslateToLocale.(level, "hu")

    assert result.persisted?
  end

  test "raises error if target locale is English" do
    level = create(:level)

    error = assert_raises ArgumentError do
      Level::Translation::TranslateToLocale.(level, "en")
    end

    assert_equal "Target locale cannot be English (en)", error.message
  end

  test "raises error if target locale is not supported" do
    level = create(:level)

    error = assert_raises ArgumentError do
      Level::Translation::TranslateToLocale.(level, "unsupported")
    end

    assert_equal "Target locale not supported", error.message
  end

  test "deletes existing translation before creating new one (upsert)" do
    level = create(:level, slug: "ruby-basics")
    existing = create(:level_translation, level:, locale: "hu", milestone_email_subject: "Old Subject")

    translation = {
      milestone_email_subject: "New Subject",
      milestone_email_content_markdown: "New Email Content"
    }
    Gemini::Translate.stubs(:call).returns(translation)

    target = Level::Translation::TranslateToLocale.(level, "hu")

    refute Level::Translation.exists?(existing.id)
    assert target.persisted?
    assert_equal "New Subject", target.milestone_email_subject
  end

  test "translation prompt includes level context" do
    level = create(:level, slug: "ruby-basics")

    command = Level::Translation::TranslateToLocale.new(level, "hu")
    prompt = command.send(:translation_prompt)

    assert_includes prompt, "Level: ruby-basics"
    assert_includes prompt, "Target Language: Hungarian (hu)"
  end

  test "translation prompt includes both source fields" do
    level = create(:level,
      milestone_email_subject: "Unique email subject",
      milestone_email_content_markdown: "Unique email content")

    command = Level::Translation::TranslateToLocale.new(level, "hu")
    prompt = command.send(:translation_prompt)

    assert_includes prompt, "Unique email subject"
    assert_includes prompt, "Unique email content"
  end

  test "translation prompt has localization expert instructions" do
    level = create(:level)

    command = Level::Translation::TranslateToLocale.new(level, "hu")
    prompt = command.send(:translation_prompt)

    assert_includes prompt, "professional localization expert"
    assert_includes prompt, "Maintain the original meaning, tone, and motivational intent"
    assert_includes prompt, "Preserve any markdown formatting"
    assert_includes prompt, "Return ONLY a valid JSON object"
  end

  # The email copy names the level, and nothing interpolates that name, so the
  # translator has to inflect it for the target language itself.
  test "translation prompt tells the model to inflect the level name" do
    command = Level::Translation::TranslateToLocale.new(create(:level), "hu")

    assert_includes command.send(:translation_prompt), "Inflect that"
  end

  test "raises Gemini::RateLimitError when rate limited" do
    level = create(:level)

    Gemini::Translate.stubs(:call).raises(Gemini::RateLimitError, "Rate limit exceeded")

    error = assert_raises Gemini::RateLimitError do
      Level::Translation::TranslateToLocale.(level, "hu")
    end

    assert_includes error.message, "Rate limit exceeded"
  end
end
