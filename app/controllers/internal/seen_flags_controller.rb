class Internal::SeenFlagsController < Internal::BaseController
  def show
    render json: { seen: current_user.seen?(params[:key]) }
  end

  def create
    User::SeenFlag::MarkSeen.(current_user, params[:key])
    render json: { seen: true }
  rescue ActiveRecord::RecordInvalid => e
    render_422(:seen_flag_invalid, errors: e.record.errors.as_json)
  end
end
