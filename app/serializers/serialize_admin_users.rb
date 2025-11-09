class SerializeAdminUsers
  include Mandate

  initialize_with :users

  def call
    users.map { |user| SerializeAdminUser.(user) }
  end
end
