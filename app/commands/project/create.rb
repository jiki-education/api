class Project::Create
  include Mandate

  initialize_with :attributes

  def call
    Project.create!(attributes)
  end
end
