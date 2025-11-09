class UserProject::Complete
  include Mandate

  initialize_with :user_project

  def call
    user_project.update!(completed_at: Time.current) if user_project.completed_at.nil?
    user_project
  end
end
