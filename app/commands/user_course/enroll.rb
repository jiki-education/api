class UserCourse::Enroll
  include Mandate

  initialize_with :user, :course

  def call
    UserCourse.find_create_or_find_by!(user:, course:).tap do
      start_first_level!
    end
  end

  private
  def start_first_level!
    first_level = course.levels.first
    UserLevel::Start.(user, first_level) if first_level
  end
end
