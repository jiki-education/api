class SerializeUserCourse
  include Mandate

  initialize_with :user_course

  def call
    {
      course_slug: user_course.course.slug,
      language: user_course.language,
      language_chosen: user_course.language_chosen?,
      current_level_slug: user_course.current_user_level&.level&.slug,
      completed: user_course.completed?
    }
  end
end
