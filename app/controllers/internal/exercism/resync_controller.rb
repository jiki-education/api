class Internal::Exercism::ResyncController < Internal::BaseController
  def create
    return render_422(:no_exercism_link) if current_user.exercism_id.blank?

    User::Exercism::ResyncUser.defer(current_user)

    render json: { user: SerializeUser.(current_user) }
  end
end
