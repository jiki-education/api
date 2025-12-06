require "test_helper"

class SerializeLevelMilestoneTest < ActiveSupport::TestCase
  test "serializes English content from Level model" do
    level = create(:level,
      slug: "ruby-basics",
      title: "Ruby Basics",
      description: "Learn Ruby",
      milestone_summary: "Great job!",
      milestone_content: "# Congratulations!")

    expected = {
      level_slug: "ruby-basics",
      title: "Ruby Basics",
      description: "Learn Ruby",
      milestone_summary: "Great job!",
      milestone_content: "# Congratulations!"
    }

    I18n.with_locale(:en) do
      assert_equal expected, SerializeLevelMilestone.(level)
    end
  end

  test "serializes translated content from Level::Translation" do
    level = create(:level,
      slug: "ruby-basics",
      title: "Ruby Basics",
      description: "Learn Ruby",
      milestone_summary: "Great job!",
      milestone_content: "# Congratulations!")

    create(:level_translation,
      level:,
      locale: "hu",
      title: "Ruby Alapok",
      description: "Tanuld meg a Ruby-t",
      milestone_summary: "Nagyszerű munka!",
      milestone_content: "# Gratulálunk!")

    expected = {
      level_slug: "ruby-basics",
      title: "Ruby Alapok",
      description: "Tanuld meg a Ruby-t",
      milestone_summary: "Nagyszerű munka!",
      milestone_content: "# Gratulálunk!"
    }

    I18n.with_locale(:hu) do
      assert_equal expected, SerializeLevelMilestone.(level)
    end
  end

  test "falls back to English when translation missing" do
    level = create(:level,
      slug: "ruby-basics",
      title: "Ruby Basics",
      description: "Learn Ruby",
      milestone_summary: "Great job!",
      milestone_content: "# Congratulations!")

    expected = {
      level_slug: "ruby-basics",
      title: "Ruby Basics",
      description: "Learn Ruby",
      milestone_summary: "Great job!",
      milestone_content: "# Congratulations!"
    }

    I18n.with_locale(:fr) do
      assert_equal expected, SerializeLevelMilestone.(level)
    end
  end

  test "includes all required fields" do
    level = create(:level)

    I18n.with_locale(:en) do
      result = SerializeLevelMilestone.(level)

      assert result.key?(:level_slug)
      assert result.key?(:title)
      assert result.key?(:description)
      assert result.key?(:milestone_summary)
      assert result.key?(:milestone_content)
    end
  end
end
