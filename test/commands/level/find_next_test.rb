require "test_helper"

class Level::FindNextTest < ActiveSupport::TestCase
  test "returns the next level by position within same course" do
    course = create(:course)
    level1 = create(:level, course:, position: 1)
    level2 = create(:level, course:, position: 2)
    create(:level, course:, position: 3)

    assert_equal level2, Level::FindNext.(level1)
  end

  test "handles gaps in position numbers" do
    course = create(:course)
    level1 = create(:level, course:, position: 1)
    level5 = create(:level, course:, position: 5)
    create(:level, course:, position: 10)

    assert_equal level5, Level::FindNext.(level1)
  end

  test "returns nil when there is no next level" do
    level = create(:level, position: 100)

    assert_nil Level::FindNext.(level)
  end

  test "returns the correct next level when multiple levels exist" do
    course = create(:course)
    create(:level, course:, position: 1)
    level2 = create(:level, course:, position: 2)
    level3 = create(:level, course:, position: 3)
    create(:level, course:, position: 4)

    assert_equal level3, Level::FindNext.(level2)
  end

  test "only finds levels within the same course" do
    course1 = create(:course)
    course2 = create(:course)
    level1_course1 = create(:level, course: course1, position: 1)
    create(:level, course: course2, position: 2) # Different course - should not be found
    level2_course1 = create(:level, course: course1, position: 3)

    assert_equal level2_course1, Level::FindNext.(level1_course1)
  end
end
