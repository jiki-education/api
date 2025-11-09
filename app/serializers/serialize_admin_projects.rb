class SerializeAdminProjects
  include Mandate

  initialize_with :projects

  def call
    projects.map do |project|
      {
        id: project.id,
        title: project.title,
        slug: project.slug,
        description: project.description,
        exercise_slug: project.exercise_slug
      }
    end
  end
end
