class UserLesson::Find
  include Mandate

  initialize_with :user, :lesson

  def call
    UserLesson.find_by!(user:, lesson:)
  rescue ActiveRecord::RecordNotFound
    raise UserLessonNotFoundError, "Lesson not started"
  end
end
