class Internal::UserVideosController < Internal::BaseController
  def index
    user_videos = current_user.user_videos.order(:slug)

    render json: {
      user_videos: user_videos.map { SerializeUserVideo.(_1) }
    }
  end

  def update
    user_video = UserVideo::SetWatchedPercentage.(current_user, params[:slug], params[:watched_percentage])

    render json: { user_video: SerializeUserVideo.(user_video) }
  end
end
