require "test_helper"

class UserCourse::AdvanceFrontierTest < ActiveSupport::TestCase
  test "sets the frontier when there isn't one" do
    user_course = create(:user_course)
    user_level = create(:user_level, user: user_course.user, level: create(:level, course: user_course.course))

    UserCourse::AdvanceFrontier.(user_course, user_level)

    assert_equal user_level, user_course.reload.current_user_level
  end

  test "advances the frontier forwards" do
    user_course = create(:user_course)
    level1 = create(:level, course: user_course.course, position: 1)
    level2 = create(:level, course: user_course.course, position: 2)
    user_level1 = create(:user_level, user: user_course.user, level: level1)
    user_level2 = create(:user_level, user: user_course.user, level: level2)
    user_course.update!(current_user_level: user_level1)

    UserCourse::AdvanceFrontier.(user_course, user_level2)

    assert_equal user_level2, user_course.reload.current_user_level
  end

  test "does not move the frontier backwards" do
    user_course = create(:user_course)
    level1 = create(:level, course: user_course.course, position: 1)
    level2 = create(:level, course: user_course.course, position: 2)
    user_level1 = create(:user_level, user: user_course.user, level: level1)
    user_level2 = create(:user_level, user: user_course.user, level: level2)
    user_course.update!(current_user_level: user_level2)

    UserCourse::AdvanceFrontier.(user_course, user_level1)

    assert_equal user_level2, user_course.reload.current_user_level
  end
end
