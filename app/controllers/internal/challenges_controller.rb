class Internal::ChallengesController < Internal::BaseController
  before_action :require_premium!, only: [:show]
  before_action :use_challenge!, only: [:show]

  def index
    challenges = Challenge::Search.(
      title: params[:title],
      page: params[:page],
      per: params[:per],
      user: current_user
    )

    render json: SerializePaginatedCollection.(
      challenges,
      serializer: SerializeChallenges,
      serializer_kwargs: { for_user: current_user }
    )
  end

  def show
    render json: {
      challenge: SerializeChallenge.(@challenge)
    }
  end
end
