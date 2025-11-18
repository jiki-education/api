class External::HealthController < External::BaseController
  def check
    # Verify database connectivity
    user = User.first

    render json: {
      ruok: true,
      sanity_data: {
        user: user&.handle || 'no_users'
      }
    }
  end
end
