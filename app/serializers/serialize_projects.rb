class SerializeProjects
  include Mandate

  initialize_with :projects, for_user: nil

  def call
    projects.map do |project|
      {
        slug: project.slug,
        title: project.title,
        description: project.description,
        status: statuses[project.id]
      }
    end
  end

  private
  memoize
  def statuses
    return Hash.new(nil) unless for_user

    # Fetch user_projects data in a single query
    user_projects_data = UserProject.
      where(user_id: for_user.id, project_id: projects.map(&:id)).
      pluck(:project_id, :started_at, :completed_at)

    # Build a hash of project_id => status with default value :locked
    user_projects_data.each_with_object(Hash.new(:locked)) do |(project_id, started_at, completed_at), hash|
      if completed_at.present?
        hash[project_id] = :completed
      elsif started_at.present?
        hash[project_id] = :started
      else
        hash[project_id] = :unlocked
      end
    end
  end
end
