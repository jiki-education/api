class Project::Update
  include Mandate

  initialize_with :project, :attributes

  def call
    project.update!(attributes)
    project
  end
end
