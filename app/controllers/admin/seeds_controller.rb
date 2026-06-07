class Admin::SeedsController < Admin::BaseController
  def create
    Rails.application.load_seed
    render json: { success: true }, status: :ok
  end
end
