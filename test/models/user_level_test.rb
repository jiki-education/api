require "test_helper"

class UserLevelTest < ActiveSupport::TestCase
  test "valid factory" do
    assert build(:user_level).valid?
  end

  test "unique user and level combination" do
    user_level = create(:user_level)

    duplicate = build(:user_level, user: user_level.user, level: user_level.level)

    refute duplicate.valid?
  end

  test "deleting user_level nullifies current_user_level reference in user_course" do
    user_level = create(:user_level)
    user_course = UserCourse.find_by(user: user_level.user, course: user_level.course)
    user_course.update!(current_user_level: user_level)

    assert_equal user_level.id, user_course.current_user_level_id

    user_level.destroy!

    user_course.reload
    assert_nil user_course.current_user_level_id
  end
end
