class UserProject::Start
  include Mandate

  initialize_with :user_project

  def call
    user_project.update!(started_at: Time.current) if user_project.started_at.nil?
    user_project
  end
end
