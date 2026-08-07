class Internal::ExerciseSubmissionsController < Internal::BaseController
  before_action :use_lesson!

  rescue_from DuplicateFilenameError, with: :render_duplicate_filename_error
  rescue_from FileTooLargeError, with: :render_file_too_large_error
  rescue_from TooManyFilesError, with: :render_too_many_files_error
  rescue_from InvalidSubmissionError, with: :render_invalid_submission_error
  rescue_from UserLevelNotFoundError, with: :render_level_not_found_error
  rescue_from LessonInProgressError, with: :render_lesson_in_progress_error
  rescue_from LessonNotUnlockedError, with: :render_lesson_not_unlocked_error
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
    render_422(:duplicate_filename, filenames: exception.filenames)
  end

  def render_file_too_large_error(exception)
    render_422(:file_too_large, filename: exception.filename, max_bytes: exception.max_bytes)
  end

  def render_too_many_files_error(exception)
    render_422(:too_many_files, count: exception.count, max: exception.max)
  end

  def render_invalid_submission_error(exception)
    render_422(:invalid_submission, reason: exception.reason)
  end

  def render_level_not_found_error(_exception) = render_error(:forbidden, "level_not_found", {}, report: false)
  def render_lesson_in_progress_error(_exception) = render_error(:forbidden, "lesson_in_progress", {}, report: false)
  def render_lesson_not_unlocked_error(_exception) = render_error(:forbidden, "lesson_not_unlocked", {}, report: false)
  def render_level_not_completed_error(_exception) = render_error(:forbidden, "level_not_completed", {}, report: false)
end
