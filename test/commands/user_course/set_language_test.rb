require "test_helper"

class UserCourse::SetLanguageTest < ActiveSupport::TestCase
  test "sets language on user_course" do
    user_course = create(:user_course)

    UserCourse::SetLanguage.(user_course, "javascript")

    assert_equal "javascript", user_course.reload.language
  end

  test "raises error if language already chosen" do
    user_course = create(:user_course, :with_javascript)

    error = assert_raises(LanguageAlreadyChosenError) do
      UserCourse::SetLanguage.(user_course, "python")
    end

    assert_equal "Language has already been chosen", error.message
  end

  test "raises error for invalid language" do
    user_course = create(:user_course)

    error = assert_raises(InvalidLanguageError) do
      UserCourse::SetLanguage.(user_course, "ruby")
    end

    assert_equal "Invalid language", error.message
  end

  test "accepts javascript" do
    user_course = create(:user_course)

    UserCourse::SetLanguage.(user_course, "javascript")

    assert_equal "javascript", user_course.reload.language
  end

  test "accepts python" do
    user_course = create(:user_course)

    UserCourse::SetLanguage.(user_course, "python")

    assert_equal "python", user_course.reload.language
  end
end
