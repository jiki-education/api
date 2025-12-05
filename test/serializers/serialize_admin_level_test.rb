require "test_helper"

class SerializeAdminLevelTest < ActiveSupport::TestCase
  test "serializes level with all attributes" do
    level = create(:level,
      slug: "ruby-basics",
      title: "Ruby Basics",
      description: "Learn the basics of Ruby",
      position: 1)

    expected = {
      id: level.id,
      slug: "ruby-basics",
      title: "Ruby Basics",
      description: "Learn the basics of Ruby",
      position: 1,
      milestone_summary: level.milestone_summary,
      milestone_content: level.milestone_content
    }

    assert_equal expected, SerializeAdminLevel.(level)
  end

  test "includes all required fields" do
    level = create(:level)

    result = SerializeAdminLevel.(level)

    assert result.key?(:id)
    assert result.key?(:slug)
    assert result.key?(:title)
    assert result.key?(:description)
    assert result.key?(:position)
    assert result.key?(:milestone_summary)
    assert result.key?(:milestone_content)
  end
end
