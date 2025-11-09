class Admin::BaseController < ApplicationController
  before_action :authenticate_user!
  before_action :ensure_admin!

  private
  def ensure_admin!
    return if current_user.admin?

    render json: {
      error: {
        type: "forbidden",
        message: "Admin access required"
      }
    }, status: :forbidden
  end
end
