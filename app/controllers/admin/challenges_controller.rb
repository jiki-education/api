class Admin::ChallengesController < Admin::BaseController
  before_action :use_challenge, only: %i[show update destroy]

  def index
    challenges = Challenge::Search.(
      query: params[:query],
      page: params[:page],
      per: params[:per]
    )

    render json: SerializePaginatedCollection.(
      challenges,
      serializer: SerializeAdminChallenges
    )
  end

  def create
    challenge = Challenge::Create.(challenge_params)
    render json: {
      challenge: SerializeAdminChallenge.(challenge)
    }, status: :created
  rescue ActiveRecord::RecordInvalid => e
    render_422(:validation_error, errors: e.record.errors.details)
  end

  def show
    render json: {
      challenge: SerializeAdminChallenge.(@challenge)
    }
  end

  def update
    challenge = Challenge::Update.(@challenge, challenge_params)
    render json: {
      challenge: SerializeAdminChallenge.(challenge)
    }
  rescue ActiveRecord::RecordInvalid => e
    render_422(:validation_error, errors: e.record.errors.details)
  end

  def destroy
    @challenge.destroy!
    head :no_content
  end

  private
  def use_challenge
    @challenge = Challenge.find(params[:id])
  rescue ActiveRecord::RecordNotFound
    render_404(:challenge_not_found)
  end

  def challenge_params
    params.require(:challenge).permit(
      :slug,
      :exercise_slug,
      :unlocked_by_lesson_id
    )
  end
end
