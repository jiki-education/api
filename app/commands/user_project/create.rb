class UserProject::Create
  include Mandate

  initialize_with :user, :project

  def call
    # Idempotent - won't fail if already exists
    UserProject.find_or_create_by!(user: user, project: project).tap do |user_project|
      add_event!(user_project)
    end
  end

  private
  def add_event!(user_project)
    # Add event only if project was newly created (not if it already existed)
    return unless user_project.previously_new_record?

    Current.add_event(:project_unlocked, {
      project: SerializeProject.(project)
    })
  end
end
