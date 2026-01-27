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
    return unless first_level

    UserLevel::Start.(user, first_level)
  end

  memoize
  def first_level = course.levels.first
end
