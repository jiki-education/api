class Internal::MeController < Internal::BaseController
  def show
    render json: { user: SerializeUser.(current_user) }
  end
end
