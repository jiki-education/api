class Internal::UserVideosController < Internal::BaseController
  def index
    user_videos = current_user.user_videos.order(:uuid)

    render json: {
      user_videos: user_videos.map { SerializeUserVideo.(_1) }
    }
  end

  def show
    user_video = current_user.user_videos.find_by!(uuid: params[:uuid])

    render json: { user_video: SerializeUserVideo.(user_video) }
  rescue ActiveRecord::RecordNotFound
    render_404(:user_video_not_found)
  end

  def update
    user_video = UserVideo::SetWatchedPercentage.(current_user, params[:uuid], params[:watched_percentage])

    render json: { user_video: SerializeUserVideo.(user_video) }
  end
end
