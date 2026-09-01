require "test_helper"

class Curriculum::RepairRegressedFrontiersTest < ActiveSupport::TestCase
  test "moves a regressed frontier forwards to the furthest level reached" do
    user_course = create(:user_course)
    level1 = create(:level, course: user_course.course, position: 1, slug: "advanced-loops")
    level2 = create(:level, course: user_course.course, position: 2)
    user_level1 = create(:user_level, user: user_course.user, level: level1)
    user_level2 = create(:user_level, user: user_course.user, level: level2)
    user_course.update!(current_user_level: user_level1)

    Curriculum::RepairRegressedFrontiers.()

    assert_equal user_level2, user_course.reload.current_user_level
  end

  test "leaves a correct frontier alone" do
    user_course = create(:user_course)
    level1 = create(:level, course: user_course.course, position: 1, slug: "advanced-loops")
    create(:level, course: user_course.course, position: 2)
    user_level1 = create(:user_level, user: user_course.user, level: level1)
    user_course.update!(current_user_level: user_level1)

    Curriculum::RepairRegressedFrontiers.()

    assert_equal user_level1, user_course.reload.current_user_level
  end

  test "ignores levels the user reached in a different course" do
    user_course = create(:user_course)
    level1 = create(:level, course: user_course.course, position: 1, slug: "advanced-loops")
    user_level1 = create(:user_level, user: user_course.user, level: level1)
    user_course.update!(current_user_level: user_level1)

    other_course = create(:course)
    create(:user_level, user: user_course.user, level: create(:level, course: other_course, position: 99))

    Curriculum::RepairRegressedFrontiers.()

    assert_equal user_level1, user_course.reload.current_user_level
  end

  test "ignores courses with no frontier" do
    user_course = create(:user_course)
    create(:user_level, user: user_course.user, level: create(:level, course: user_course.course))
    user_course.update!(current_user_level: nil)

    Curriculum::RepairRegressedFrontiers.()

    assert_nil user_course.reload.current_user_level
  end

  test "leaves frontiers on other levels alone" do
    user_course = create(:user_course)
    level1 = create(:level, course: user_course.course, position: 1, slug: "multiple-functions")
    level2 = create(:level, course: user_course.course, position: 2)
    user_level1 = create(:user_level, user: user_course.user, level: level1)
    create(:user_level, user: user_course.user, level: level2)
    user_course.update!(current_user_level: user_level1)

    Curriculum::RepairRegressedFrontiers.()

    assert_equal user_level1, user_course.reload.current_user_level
  end
end
