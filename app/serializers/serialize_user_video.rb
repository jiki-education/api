class SerializeUserVideo
  include Mandate

  initialize_with :user_video

  def call
    {
      slug: user_video.slug,
      watched_percentage: user_video.watched_percentage,
      status: user_video.completed_at ? "completed" : "started",
      completed_at: user_video.completed_at&.iso8601
    }
  end
end
