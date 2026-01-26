require "test_helper"

class UserCourse::EnrollTest < ActiveSupport::TestCase
  test "creates user_course for new enrollment" do
    user = create(:user)
    course = create(:course)

    assert_difference -> { UserCourse.count }, 1 do
      UserCourse::Enroll.(user, course)
    end
  end

  test "returns created user_course" do
    user = create(:user)
    course = create(:course)

    result = UserCourse::Enroll.(user, course)

    assert_instance_of UserCourse, result
    assert_equal user.id, result.user_id
    assert_equal course.id, result.course_id
  end

  test "sets created_at on creation" do
    user = create(:user)
    course = create(:course)

    time_before = Time.current
    result = UserCourse::Enroll.(user, course)
    time_after = Time.current

    assert result.created_at >= time_before
    assert result.created_at <= time_after
  end

  test "is idempotent - returns existing user_course on duplicate" do
    user = create(:user)
    course = create(:course)
    first_result = UserCourse::Enroll.(user, course)

    assert_no_difference -> { UserCourse.count } do
      second_result = UserCourse::Enroll.(user, course)
      assert_equal first_result.id, second_result.id
    end
  end

  test "allows same user to enroll in different courses" do
    user = create(:user)
    course1 = create(:course)
    course2 = create(:course)

    result1 = UserCourse::Enroll.(user, course1)
    result2 = UserCourse::Enroll.(user, course2)

    refute_equal result1.id, result2.id
    assert_equal 2, user.user_courses.count
  end

  test "allows different users to enroll in same course" do
    user1 = create(:user)
    user2 = create(:user)
    course = create(:course)

    result1 = UserCourse::Enroll.(user1, course)
    result2 = UserCourse::Enroll.(user2, course)

    refute_equal result1.id, result2.id
    assert_equal 2, course.user_courses.count
  end

  test "initializes with nil language" do
    user = create(:user)
    course = create(:course)

    result = UserCourse::Enroll.(user, course)

    assert_nil result.language
  end

  test "initializes with nil completed_at" do
    user = create(:user)
    course = create(:course)

    result = UserCourse::Enroll.(user, course)

    assert_nil result.completed_at
  end
end
