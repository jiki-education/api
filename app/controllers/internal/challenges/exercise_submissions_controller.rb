class Internal::Challenges::ExerciseSubmissionsController < Internal::BaseController
  before_action :require_premium!
  before_action :use_challenge!

  rescue_from DuplicateFilenameError, with: :render_duplicate_filename_error
  rescue_from FileTooLargeError, with: :render_file_too_large_error
  rescue_from TooManyFilesError, with: :render_too_many_files_error
  rescue_from InvalidSubmissionError, with: :render_invalid_submission_error
  rescue_from ChallengeLockedError, with: :render_challenge_locked_error

  def create
    # Start the challenge for current user (idempotent, validates unlock)
    user_challenge = UserChallenge::Start.(current_user, @challenge)

    # Create submission with UserChallenge as context
    ExerciseSubmission::Create.(
      user_challenge,
      submission_params[:files],
      progression_scores: submission_params[:progression_scores]
    )

    render json: {}, status: :created
  end

  private
  def submission_params
    params.require(:submission).permit(files: %i[filename code], progression_scores: {})
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

  def render_challenge_locked_error(_exception)
    render_403(:challenge_locked)
  end
end
