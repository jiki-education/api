class UserLesson::SetWalkthroughVideoPercentage
  include Mandate

  initialize_with :user, :lesson, :percentage

  def call
    clamped = percentage.to_i.clamp(0, 100)

    return if user_lesson.walkthrough_video_watched_percentage && user_lesson.walkthrough_video_watched_percentage >= clamped

    user_lesson.update!(walkthrough_video_watched_percentage: clamped)
  end

  private
  memoize
  def user_lesson = UserLesson::Find.(user, lesson)
end
