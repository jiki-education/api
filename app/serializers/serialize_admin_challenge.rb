class SerializeAdminChallenge
  include Mandate

  initialize_with :challenge

  def call
    {
      id: challenge.id,
      title: challenge.title,
      slug: challenge.slug,
      description: challenge.description,
      exercise_slug: challenge.exercise_slug
    }
  end
end
