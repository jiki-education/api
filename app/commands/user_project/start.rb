class UserProject::Start
  include Mandate

  initialize_with :user, :project

  def call
    raise ProjectLockedError, "Project is locked" unless UserProject::UnlockedForUser.(user, project)

    UserProject.find_or_create_by!(user:, project:).tap do |user_project|
      user_project.update!(started_at: Time.current) if user_project.started_at.nil?
    end
  end
end
