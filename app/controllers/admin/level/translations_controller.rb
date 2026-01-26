class Admin::Level::TranslationsController < Admin::BaseController
  before_action :set_course
  before_action :set_level

  def translate
    target_locales = Level::Translation::TranslateToAllLocales.(@level)

    render json: {
      level_slug: @level.slug,
      queued_locales: target_locales
    }, status: :accepted
  end

  private
  def set_course
    @course = Course.find_by!(slug: params[:course_slug])
  rescue ActiveRecord::RecordNotFound
    render_not_found("Course not found")
  end

  def set_level
    @level = @course.levels.find(params[:level_id])
  rescue ActiveRecord::RecordNotFound
    render_not_found("Level not found")
  end
end
