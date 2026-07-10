class SerializeAdminChallenges
  include Mandate

  initialize_with :challenges

  def call
    challenges.map do |challenge|
      {
        id: challenge.id,
        title: challenge.title,
        slug: challenge.slug,
        description: challenge.description,
        exercise_slug: challenge.exercise_slug
      }
    end
  end
end
