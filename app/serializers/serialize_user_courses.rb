class SerializeUserCourses
  include Mandate

  initialize_with :user_courses

  def call
    user_courses.includes(:course, current_user_level: :level).map do |user_course|
      SerializeUserCourse.(user_course)
    end
  end
end
