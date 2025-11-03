class SerializeAdminProject
  include Mandate

  initialize_with :project

  def call
    {
      id: project.id,
      title: project.title,
      slug: project.slug,
      description: project.description,
      exercise_slug: project.exercise_slug
    }
  end
end
