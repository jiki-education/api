class SerializeAdminChallenges
  include Mandate

  initialize_with :challenges

  def call
    challenges.map do |challenge|
      {
        id: challenge.id,
        slug: challenge.slug,
        exercise_slug: challenge.exercise_slug
      }
    end
  end
end
