class UserChallenge::Complete
  include Mandate

  initialize_with :user_challenge

  def call
    user_challenge.update!(completed_at: Time.current) if user_challenge.completed_at.nil?
    user_challenge
  end
end
