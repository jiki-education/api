class Dev::BaseController < ApplicationController
  skip_before_action :authenticate_user!

  before_action :ensure_development_environment!

  private
  def ensure_development_environment!
    return if Rails.env.development?

    render json: {
      error: {
        type: "not_found",
        message: "Not found"
      }
    }, status: :not_found
  end
end
