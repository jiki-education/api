require "test_helper"

class SerializeAdminLevelTranslationTest < ActiveSupport::TestCase
  test "serializes translation with all attributes" do
    level = create(:level, slug: "ruby-basics")
    translation = create(:level_translation,
      level:,
      locale: "hu",
      title: "Ruby Alapok",
      description: "Tanuld meg a Ruby-t",
      milestone_summary: "Nagyszerű munka!",
      milestone_content: "# Gratulálunk!")

    expected = {
      id: translation.id,
      level_slug: "ruby-basics",
      locale: "hu",
      title: "Ruby Alapok",
      description: "Tanuld meg a Ruby-t",
      milestone_summary: "Nagyszerű munka!",
      milestone_content: "# Gratulálunk!"
    }

    assert_equal expected, SerializeAdminLevelTranslation.(translation)
  end

  test "includes all required fields" do
    level = create(:level)
    translation = create(:level_translation, level:)

    result = SerializeAdminLevelTranslation.(translation)

    assert result.key?(:id)
    assert result.key?(:level_slug)
    assert result.key?(:locale)
    assert result.key?(:title)
    assert result.key?(:description)
    assert result.key?(:milestone_summary)
    assert result.key?(:milestone_content)
  end
end
