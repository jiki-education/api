class Internal::ExerciseSubmissionsController < Internal::BaseController
  before_action :use_lesson!, only: %i[latest create]
  before_action :use_submission!, only: :update

  rescue_from DuplicateFilenameError, with: :render_duplicate_filename_error
  rescue_from FileTooLargeError, with: :render_file_too_large_error
  rescue_from TooManyFilesError, with: :render_too_many_files_error
  rescue_from InvalidSubmissionError, with: :render_invalid_submission_error
  rescue_from UserLevelNotFoundError, with: :render_level_not_found_error
  rescue_from LessonInProgressError, with: :render_lesson_in_progress_error
  rescue_from LevelNotCompletedError, with: :render_level_not_completed_error

  def latest
    user_lesson = UserLesson.find_by(user: current_user, lesson: @lesson)
    return render_404(:not_found) unless user_lesson

    last_submission = user_lesson.exercise_submissions.
      includes(files: { content_attachment: :blob }).
      order(id: :desc).
      first

    return render_404(:not_found) unless last_submission

    render json: {
      submission: SerializeExerciseSubmission.(last_submission)
    }
  end

  def create
    # Start lesson for current user (idempotent if already started)
    user_lesson = UserLesson::Start.(current_user, @lesson)

    # Create submission with UserLesson as context
    submission = ExerciseSubmission::Create.(
      user_lesson,
      submission_params[:files]
    )

    # Return only the identifier: the client already has the files, and uses
    # the uuid to patch progression scores in a follow-up request.
    render json: {
      submission: { uuid: submission.uuid }
    }, status: :created
  end

  def update
    ExerciseSubmission::UpdateProgressionScores.(
      @submission,
      progression_scores_params[:progression_scores]
    )

    render json: {}, status: :ok
  end

  private
  def submission_params
    params.require(:submission).permit(files: %i[filename code])
  end

  def progression_scores_params
    params.require(:submission).permit(progression_scores: {})
  end

  # Looks up a submission by uuid, scoped to the current user (a submission
  # delegates #user to its polymorphic context), 404ing otherwise.
  def use_submission!
    @submission = ExerciseSubmission.find_by(uuid: params[:uuid])
    render_404(:exercise_submission_not_found) unless @submission&.user == current_user
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

  def render_level_not_found_error(exception)
    render json: {
      error: {
        type: "level_not_found",
        message: exception.message
      }
    }, status: :forbidden
  end

  def render_lesson_in_progress_error(exception)
    render json: {
      error: {
        type: "lesson_in_progress",
        message: exception.message
      }
    }, status: :forbidden
  end

  def render_level_not_completed_error(exception)
    render json: {
      error: {
        type: "level_not_completed",
        message: exception.message
      }
    }, status: :forbidden
  end
end
