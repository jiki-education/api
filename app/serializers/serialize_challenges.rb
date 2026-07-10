class SerializeChallenges
  include Mandate

  initialize_with :challenges, for_user: nil

  def call
    challenges.map do |challenge|
      {
        slug: challenge.slug,
        title: challenge.title,
        description: challenge.description,
        status: statuses[challenge.id]
      }
    end
  end

  private
  memoize
  def statuses
    return Hash.new(nil) unless for_user

    challenges.to_h { |challenge| [challenge.id, status_for(challenge)] }
  end

  def status_for(challenge)
    row = user_challenge_rows[challenge.id]

    return :completed if row && row[:completed_at].present?
    return :started if row && row[:started_at].present?
    return :unlocked if unlocked_challenge_ids.include?(challenge.id)

    :locked
  end

  memoize
  def user_challenge_rows
    UserChallenge.
      where(user_id: for_user.id, challenge_id: challenges.map(&:id)).
      pluck(:challenge_id, :started_at, :completed_at).
      to_h { |challenge_id, started_at, completed_at| [challenge_id, { started_at:, completed_at: }] }
  end

  # A challenge is unlocked when it has no unlocking lesson, or the user has
  # completed the lesson that unlocks it.
  memoize
  def unlocked_challenge_ids
    completed_lesson_ids = UserLesson.
      where(user_id: for_user.id, lesson_id: challenges.map(&:unlocked_by_lesson_id).compact).
      where.not(completed_at: nil).
      pluck(:lesson_id).
      to_set

    challenges.
      select { |p| p.unlocked_by_lesson_id.nil? || completed_lesson_ids.include?(p.unlocked_by_lesson_id) }.
      map(&:id).
      to_set
  end
end
