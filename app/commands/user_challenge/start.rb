class UserChallenge::Start
  include Mandate

  initialize_with :user, :challenge

  def call
    raise ChallengeLockedError, "Challenge is locked" unless UserChallenge::UnlockedForUser.(user, challenge)

    UserChallenge.find_or_create_by!(user:, challenge:).tap do |user_challenge|
      user_challenge.update!(started_at: Time.current) if user_challenge.started_at.nil?
    end
  end
end
