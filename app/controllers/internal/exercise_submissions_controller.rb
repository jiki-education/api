class Internal::ExerciseSubmissionsController < Internal::BaseController
  before_action :use_lesson!

  rescue_from DuplicateFilenameError, with: :render_duplicate_filename_error
  rescue_from FileTooLargeError, with: :render_file_too_large_error
  rescue_from TooManyFilesError, with: :render_too_many_files_error
  rescue_from InvalidSubmissionError, with: :render_invalid_submission_error

  def create
    # Find or create UserLesson for current user and lesson
    user_lesson = UserLesson::FindOrCreate.(current_user, @lesson)

    # Create submission with UserLesson as context
    ExerciseSubmission::Create.(
      user_lesson,
      submission_params[:files]
    )

    render json: {}, status: :created
  end

  private
  def submission_params
    params.require(:submission).permit(files: %i[filename code])
  end

  def render_duplicate_filename_error(exception)
    render json: {
      error: {
        type: "duplicate_filename",
        message: exception.message
      }
    }, status: :unprocessable_entity
  end

  def render_file_too_large_error(exception)
    render json: {
      error: {
        type: "file_too_large",
        message: exception.message
      }
    }, status: :unprocessable_entity
  end

  def render_too_many_files_error(exception)
    render json: {
      error: {
        type: "too_many_files",
        message: exception.message
      }
    }, status: :unprocessable_entity
  end

  def render_invalid_submission_error(exception)
    render json: {
      error: {
        type: "invalid_submission",
        message: exception.message
      }
    }, status: :unprocessable_entity
  end
end
