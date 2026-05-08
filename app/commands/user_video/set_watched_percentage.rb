class UserVideo::SetWatchedPercentage
  include Mandate

  initialize_with :user, :slug, :percentage

  def call
    clamped = percentage.to_i.clamp(0, 100)

    return user_video if user_video.watched_percentage >= clamped

    attrs = { watched_percentage: clamped }
    attrs[:completed_at] = Time.current if clamped == 100 && user_video.completed_at.nil?
    user_video.update!(attrs)
    user_video
  end

  private
  memoize
  def user_video
    UserVideo.find_or_create_by!(user:, slug:)
  end
end
