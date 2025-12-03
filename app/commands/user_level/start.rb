class UserLevel::Start
  include Mandate

  initialize_with :user, :level

  def call
    UserLevel.find_create_or_find_by!(user:, level:)
  end
end
