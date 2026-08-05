require "test_helper"

class SerializeAdminLevelsTest < ActiveSupport::TestCase
  test "serializes multiple levels" do
    level_1 = create(:level, slug: "level-1")
    level_2 = create(:level, slug: "level-2")

    expected = [
      { id: level_1.id, slug: "level-1", position: level_1.position },
      { id: level_2.id, slug: "level-2", position: level_2.position }
    ]

    assert_equal expected, SerializeAdminLevels.([level_1, level_2])
  end

  test "serializes empty array" do
    assert_empty SerializeAdminLevels.([])
  end

  test "calls SerializeAdminLevel for each level" do
    level_1 = create(:level)
    level_2 = create(:level, slug: "level-2")

    SerializeAdminLevel.expects(:call).with(level_1).returns({ id: level_1.id })
    SerializeAdminLevel.expects(:call).with(level_2).returns({ id: level_2.id })

    SerializeAdminLevels.([level_1, level_2])
  end
end
