class Admin::Level::TranslationsController < Admin::BaseController
  before_action :set_level

  def translate
    target_locales = Level::Translation::TranslateToAllLocales.(@level)

    render json: {
      level_slug: @level.slug,
      queued_locales: target_locales
    }, status: :accepted
  end

  private
  def set_level
    @level = Level.find_by!(slug: params[:level_id])
  rescue ActiveRecord::RecordNotFound
    render_not_found("Level not found")
  end
end
