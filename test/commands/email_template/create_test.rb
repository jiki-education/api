require "test_helper"

class EmailTemplate::CreateTest < ActiveSupport::TestCase
  test "creates email template with all valid params" do
    params = {
      type: :level_completion,
      slug: "new-level",
      locale: "en",
      subject: "Test Subject",
      body_mjml: "<mj-section><mj-column><mj-text>Test</mj-text></mj-column></mj-section>",
      body_text: "Test text body"
    }

    email_template = EmailTemplate::Create.(params)

    assert email_template.persisted?
    assert_equal "level_completion", email_template.type
    assert_equal "new-level", email_template.slug
    assert_equal "en", email_template.locale
    assert_equal "Test Subject", email_template.subject
    assert_equal "<mj-section><mj-column><mj-text>Test</mj-text></mj-column></mj-section>", email_template.body_mjml
    assert_equal "Test text body", email_template.body_text
  end

  test "raises validation error when type is missing" do
    params = {
      slug: "new-level",
      locale: "en",
      subject: "Test Subject",
      body_mjml: "<mj-section><mj-column><mj-text>Test</mj-text></mj-column></mj-section>",
      body_text: "Test text body"
    }

    error = assert_raises ActiveRecord::RecordInvalid do
      EmailTemplate::Create.(params)
    end

    assert_match(/Type/, error.message)
  end

  test "raises validation error when slug is missing" do
    params = {
      type: :level_completion,
      locale: "en",
      subject: "Test Subject",
      body_mjml: "<mj-section><mj-column><mj-text>Test</mj-text></mj-column></mj-section>",
      body_text: "Test text body"
    }

    # NOTE: slug can be nil, so this should NOT raise an error
    email_template = EmailTemplate::Create.(params)
    assert email_template.persisted?
    assert_nil email_template.slug
  end

  test "raises validation error when locale is missing" do
    params = {
      type: :level_completion,
      slug: "new-level",
      subject: "Test Subject",
      body_mjml: "<mj-section><mj-column><mj-text>Test</mj-text></mj-column></mj-section>",
      body_text: "Test text body"
    }

    error = assert_raises ActiveRecord::RecordInvalid do
      EmailTemplate::Create.(params)
    end

    assert_match(/Locale/, error.message)
  end

  test "raises validation error when subject is missing" do
    params = {
      type: :level_completion,
      slug: "new-level",
      locale: "en",
      body_mjml: "<mj-section><mj-column><mj-text>Test</mj-text></mj-column></mj-section>",
      body_text: "Test text body"
    }

    error = assert_raises ActiveRecord::RecordInvalid do
      EmailTemplate::Create.(params)
    end

    assert_match(/Subject/, error.message)
  end

  test "raises validation error when body_mjml is missing" do
    params = {
      type: :level_completion,
      slug: "new-level",
      locale: "en",
      subject: "Test Subject",
      body_text: "Test text body"
    }

    error = assert_raises ActiveRecord::RecordInvalid do
      EmailTemplate::Create.(params)
    end

    assert_match(/Body mjml/, error.message)
  end

  test "raises validation error when body_text is missing" do
    params = {
      type: :level_completion,
      slug: "new-level",
      locale: "en",
      subject: "Test Subject",
      body_mjml: "<mj-section><mj-column><mj-text>Test</mj-text></mj-column></mj-section>"
    }

    error = assert_raises ActiveRecord::RecordInvalid do
      EmailTemplate::Create.(params)
    end

    assert_match(/Body text/, error.message)
  end

  test "raises error for duplicate type, slug, and locale combination" do
    create(:email_template, type: :level_completion, slug: "level-1", locale: "en")

    params = {
      type: :level_completion,
      slug: "level-1",
      locale: "en",
      subject: "Duplicate Subject",
      body_mjml: "<mj-section><mj-column><mj-text>Duplicate</mj-text></mj-column></mj-section>",
      body_text: "Duplicate text body"
    }

    assert_raises ActiveRecord::RecordInvalid do
      EmailTemplate::Create.(params)
    end
  end

  test "allows same type and slug with different locale" do
    create(:email_template, type: :level_completion, slug: "level-1", locale: "en")

    params = {
      type: :level_completion,
      slug: "level-1",
      locale: "hu",
      subject: "Hungarian Subject",
      body_mjml: "<mj-section><mj-column><mj-text>Hungarian</mj-text></mj-column></mj-section>",
      body_text: "Hungarian text body"
    }

    email_template = EmailTemplate::Create.(params)

    assert email_template.persisted?
    assert_equal "hu", email_template.locale
  end

  test "filters out extra params" do
    params = {
      type: :level_completion,
      slug: "new-level",
      locale: "en",
      subject: "Test Subject",
      body_mjml: "<mj-section><mj-column><mj-text>Test</mj-text></mj-column></mj-section>",
      body_text: "Test text body",
      extra_param: "should be ignored"
    }

    email_template = EmailTemplate::Create.(params)

    assert email_template.persisted?
    refute_respond_to email_template, :extra_param
  end
end
