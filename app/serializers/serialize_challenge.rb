class SerializeChallenge
  include Mandate

  initialize_with :challenge

  def call
    {
      slug: challenge.slug,
      exercise_slug: challenge.exercise_slug
    }
  end
end
