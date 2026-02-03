class Dev::BaseController < ApplicationController
  before_action :ensure_development_environment!

  private
  def ensure_development_environment!
    return if Rails.env.development?

    render_404(:not_found)
  end
end
