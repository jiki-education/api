class UserLesson::SetRatings
  include Mandate

  initialize_with :user, :lesson, :difficulty_rating, :fun_rating

  def call
    user_lesson = UserLesson.find_by!(user:, lesson:)
    user_lesson.update!(
      difficulty_rating: difficulty_rating,
      fun_rating: fun_rating
    )
  rescue ActiveRecord::RecordNotFound
    raise UserLessonNotFoundError
  end
end
