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
      position: 1
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
  end
end
