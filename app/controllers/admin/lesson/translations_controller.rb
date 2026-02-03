class Admin::Lesson::TranslationsController < Admin::BaseController
  before_action :set_lesson

  def translate
    target_locales = Lesson::Translation::TranslateToAllLocales.(@lesson)

    render json: {
      lesson_slug: @lesson.slug,
      queued_locales: target_locales
    }, status: :accepted
  end

  private
  def set_lesson
    @lesson = Lesson.find_by!(slug: params[:lesson_id])
  rescue ActiveRecord::RecordNotFound
    render_404(:lesson_not_found)
  end
end
