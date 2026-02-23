class UserLesson::SetRatings
  include Mandate

  initialize_with :user, :lesson, :difficulty_rating, :fun_rating

  def call
    user_lesson.update!(
      difficulty_rating: difficulty_rating,
      fun_rating: fun_rating
    )
  end

  private
  memoize
  def user_lesson
    UserLesson::Find.(user, lesson)
  rescue ActiveRecord::RecordNotFound
    raise UserLessonNotFoundError
  end
end
