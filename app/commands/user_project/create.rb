class UserProject::Create
  include Mandate

  initialize_with :user, :project

  def call
    # Idempotent - won't fail if already exists
    UserProject.find_or_create_by!(user:, project:)
  end
end
