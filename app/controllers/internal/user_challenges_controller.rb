class Internal::UserChallengesController < Internal::BaseController
  before_action :require_premium!
  before_action :use_challenge!
  before_action :use_user_challenge!, only: %i[show complete]

  def show
    render json: {
      user_challenge: SerializeUserChallenge.(@user_challenge)
    }
  end

  def start
    UserChallenge::Start.(current_user, @challenge)

    render json: {}
  rescue ChallengeLockedError
    render_403(:challenge_locked)
  end

  def complete
    UserChallenge::Complete.(@user_challenge)

    render json: {}
  end
end
