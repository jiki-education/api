class SerializeProject
  include Mandate

  initialize_with :project

  def call
    {
      slug: project.slug,
      title: project.title,
      description: project.description
    }
  end
end
