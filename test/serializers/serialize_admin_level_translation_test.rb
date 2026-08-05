require "test_helper"

class SerializeAdminLevelTranslationTest < ActiveSupport::TestCase
  test "serializes translation with all attributes" do
    level = create(:level, slug: "ruby-basics")
    translation = create(:level_translation,
      level:,
      locale: "hu",
      milestone_email_subject: "Gratulálunk!",
      milestone_email_content_markdown: "Befejezted az összes leckét.")

    expected = {
      id: translation.id,
      level_slug: "ruby-basics",
      locale: "hu",
      milestone_email_subject: "Gratulálunk!",
      milestone_email_content_markdown: "Befejezted az összes leckét."
    }

    assert_equal expected, SerializeAdminLevelTranslation.(translation)
  end
end
