class Internal::ProfilesController < Internal::BaseController
  def show
    render json: { profile: SerializeProfile.(current_user) }
  end
end
