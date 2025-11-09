require "test_helper"

class EmailTemplate::TranslateToLocaleTest < ActiveSupport::TestCase
  test "creates translated template with correct attributes" do
    source = create(:email_template, type: :level_completion, slug: "level-1", locale: "en")

    translation = {
      subject: "Translated Subject",
      body_mjml: "<mj-text>Translated MJML</mj-text>",
      body_text: "Translated plain text"
    }
    Gemini::Translate.stubs(:call).returns(translation)

    target = EmailTemplate::TranslateToLocale.(source, "hu")

    assert target.persisted?
    assert_equal "level_completion", target.type
    assert_equal "level-1", target.slug
    assert_equal "hu", target.locale
    assert_equal "Translated Subject", target.subject
    assert_equal "<mj-text>Translated MJML</mj-text>", target.body_mjml
    assert_equal "Translated plain text", target.body_text
  end

  test "calls Gemini::Translate with correct parameters" do
    source = create(:email_template, type: :level_completion, slug: "level-1", locale: "en")

    translation = {
      subject: "Test",
      body_mjml: "Test",
      body_text: "Test"
    }

    # Verify Gemini::Translate is called with correct params
    Gemini::Translate.expects(:call).with(
      instance_of(String), # The full prompt
      model: :flash
    ).returns(translation)

    result = EmailTemplate::TranslateToLocale.(source, "hu")

    assert result.persisted?
  end

  test "raises error if source template is not English" do
    source = create(:email_template, :hungarian, locale: "hu")

    error = assert_raises ArgumentError do
      EmailTemplate::TranslateToLocale.(source, "fr")
    end

    assert_equal "Source template must be in English (en)", error.message
  end

  test "raises error if target locale is English" do
    source = create(:email_template, locale: "en")

    error = assert_raises ArgumentError do
      EmailTemplate::TranslateToLocale.(source, "en")
    end

    assert_equal "Target locale cannot be English (en)", error.message
  end

  test "raises error if target locale is not supported" do
    source = create(:email_template, locale: "en")

    error = assert_raises ArgumentError do
      EmailTemplate::TranslateToLocale.(source, "unsupported")
    end

    assert_equal "Target locale not supported", error.message
  end

  test "deletes existing template before creating new one (upsert)" do
    source = create(:email_template, type: :level_completion, slug: "level-1", locale: "en")
    existing = create(:email_template, type: :level_completion, slug: "level-1", locale: "hu", subject: "Old")

    translation = {
      subject: "New Subject",
      body_mjml: "New MJML",
      body_text: "New Text"
    }
    Gemini::Translate.stubs(:call).returns(translation)

    target = EmailTemplate::TranslateToLocale.(source, "hu")

    refute EmailTemplate.exists?(existing.id)
    assert target.persisted?
    assert_equal "New Subject", target.subject # New translated subject, not old subject
  end

  test "translation prompt includes all required context" do
    source = create(:email_template,
      type: :level_completion,
      slug: "level-1",
      locale: "en",
      subject: "Test Subject")

    translation = {
      subject: "Test",
      body_mjml: "Test",
      body_text: "Test"
    }
    Gemini::Translate.stubs(:call).returns(translation)

    EmailTemplate::TranslateToLocale.(source, "hu")

    # Verify the prompt was built correctly by checking the command
    # The prompt is memoized and built during initialization
    command = EmailTemplate::TranslateToLocale.new(source, "hu")
    prompt = command.send(:translation_prompt)

    assert_includes prompt, "Template Type: level_completion"
    assert_includes prompt, "Template Slug: level-1"
    assert_includes prompt, "Target Language: Hungarian (hu)"
  end

  test "translation prompt includes all three fields (subject, body_mjml, body_text)" do
    source = create(:email_template,
      locale: "en",
      subject: "Unique Subject Line",
      body_mjml: "<mj-text>Unique MJML Content</mj-text>",
      body_text: "Unique plain text content")

    command = EmailTemplate::TranslateToLocale.new(source, "hu")
    prompt = command.send(:translation_prompt)

    assert_includes prompt, "Unique Subject Line"
    assert_includes prompt, "<mj-text>Unique MJML Content</mj-text>"
    assert_includes prompt, "Unique plain text content"
  end

  test "translation prompt has localization expert instructions" do
    source = create(:email_template, locale: "en")

    command = EmailTemplate::TranslateToLocale.new(source, "hu")
    prompt = command.send(:translation_prompt)

    assert_includes prompt, "professional localization expert"
    assert_includes prompt, "Maintain the original meaning, tone, and intent"
    assert_includes prompt, "DO NOT translate MJML tags"
    assert_includes prompt, "Preserve variable placeholders"
    assert_includes prompt, "Return ONLY a valid JSON object"
  end

  test "raises Gemini::RateLimitError when rate limited" do
    source = create(:email_template, locale: "en")

    Gemini::Translate.stubs(:call).raises(Gemini::RateLimitError, "Rate limit exceeded")

    error = assert_raises Gemini::RateLimitError do
      EmailTemplate::TranslateToLocale.(source, "hu")
    end

    assert_includes error.message, "Rate limit exceeded"
  end
end
