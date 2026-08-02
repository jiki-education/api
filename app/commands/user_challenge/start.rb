class UserChallenge::Start
  include Mandate

  initialize_with :user, :challenge

  def call
    raise ChallengeLockedError, "Challenge is locked" unless UserChallenge::UnlockedForUser.(user, challenge)

    user_challenge.tap do |uc|
      uc.update!(started_at: Time.current) if uc.started_at.nil?
    end
  end

  private
  def user_challenge
    UserChallenge.find_or_create_by!(user:, challenge:)
  rescue ActiveRecord::RecordInvalid, ActiveRecord::RecordNotUnique
    UserChallenge.find_by!(user:, challenge:)
  end
end
