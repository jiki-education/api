require "test_helper"

class SerializeAdminLevelTest < ActiveSupport::TestCase
  test "serializes level with all attributes" do
    level = create(:level, slug: "ruby-basics", position: 1)

    expected = {
      id: level.id,
      slug: "ruby-basics",
      position: 1
    }

    assert_equal expected, SerializeAdminLevel.(level)
  end

  # Level copy is authored in the front-end curriculum repo.
  test "does not include title or description" do
    result = SerializeAdminLevel.(create(:level))

    refute result.key?(:title)
    refute result.key?(:description)
  end
end
