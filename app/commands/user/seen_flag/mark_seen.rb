class User::SeenFlag::MarkSeen
  include Mandate

  initialize_with :user, :key

  def call
    User::SeenFlag.find_or_create_by!(user:, key:)
  rescue ActiveRecord::RecordNotUnique
    nil
  end
end
