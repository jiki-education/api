require "test_helper"

class SerializeAdminEmailTemplatesTest < ActiveSupport::TestCase
  test "serializes collection with limited fields" do
    template1 = create(:email_template, slug: "template-1", locale: "en")
    template2 = create(:email_template, slug: "template-2", locale: "hu")

    expected = [
      {
        id: template1.id,
        type: "level_completion",
        slug: "template-1",
        locale: "en"
      },
      {
        id: template2.id,
        type: "level_completion",
        slug: "template-2",
        locale: "hu"
      }
    ]

    assert_equal expected, SerializeAdminEmailTemplates.([template1, template2])
  end

  test "returns empty array for empty collection" do
    assert_empty SerializeAdminEmailTemplates.([])
  end

  test "does not include full body content in collection view" do
    template = create(:email_template,
      subject: "Long subject",
      body_mjml: "<mj-section>Long MJML content</mj-section>",
      body_text: "Long text content")

    result = SerializeAdminEmailTemplates.([template]).first

    refute result.key?(:subject), "Should not include subject in collection view"
    refute result.key?(:body_mjml), "Should not include body_mjml in collection view"
    refute result.key?(:body_text), "Should not include body_text in collection view"
  end

  test "serializes multiple templates correctly" do
    template1 = create(:email_template, slug: "test-1", locale: "en")
    template2 = create(:email_template, slug: "test-2", locale: "en")
    template3 = create(:email_template, slug: "test-3", locale: "en")
    templates = [template1, template2, template3]

    result = SerializeAdminEmailTemplates.(templates)

    assert_equal 3, result.length
    result.each_with_index do |serialized, index|
      assert_equal templates[index].id, serialized[:id]
      assert_equal templates[index].type, serialized[:type]
      assert_equal templates[index].slug, serialized[:slug]
      assert_equal templates[index].locale, serialized[:locale]
    end
  end
end
