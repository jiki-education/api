class UserCourse::Enroll
  include Mandate

  initialize_with :user, :course

  def call
    UserCourse.find_create_or_find_by!(user:, course:)
  end
end
