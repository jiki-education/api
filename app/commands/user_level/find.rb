class UserLevel::Find
  include Mandate

  initialize_with :user, :level

  def call
    UserLevel.find_by!(user:, level:)
  rescue ActiveRecord::RecordNotFound
    raise UserLevelNotFoundError, "Level not available"
  end
end
