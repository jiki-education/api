class User::Flag::Mark
  include Mandate

  initialize_with :user, :key

  def call
    User::Flag.find_or_create_by!(user:, key:)
  rescue ActiveRecord::RecordNotUnique
    nil
  end
end
