require "test_helper"

class SerializeAdminEmailTemplateTest < ActiveSupport::TestCase
  test "serializes all fields correctly" do
    email_template = create(:email_template,
      slug: "test-template",
      locale: "en",
      subject: "Test Subject",
      body_mjml: "<mj-section><mj-column><mj-text>Test</mj-text></mj-column></mj-section>",
      body_text: "Test text body")

    expected = {
      id: email_template.id,
      type: "level_completion",
      slug: "test-template",
      locale: "en",
      subject: "Test Subject",
      body_mjml: "<mj-section><mj-column><mj-text>Test</mj-text></mj-column></mj-section>",
      body_text: "Test text body"
    }

    assert_equal expected, SerializeAdminEmailTemplate.(email_template)
  end

  test "serializes Hungarian template" do
    email_template = create(:email_template, :hungarian, slug: "hungarian-test")

    result = SerializeAdminEmailTemplate.(email_template)

    assert_equal "hu", result[:locale]
    assert_equal "hungarian-test", result[:slug]
    assert_equal email_template.id, result[:id]
  end

  test "includes type as string" do
    email_template = create(:email_template, type: :level_completion)

    result = SerializeAdminEmailTemplate.(email_template)

    assert_equal "level_completion", result[:type]
    assert_kind_of String, result[:type]
  end
end
