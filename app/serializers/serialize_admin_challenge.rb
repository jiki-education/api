class SerializeAdminChallenge
  include Mandate

  initialize_with :challenge

  def call
    {
      id: challenge.id,
      slug: challenge.slug,
      exercise_slug: challenge.exercise_slug
    }
  end
end
