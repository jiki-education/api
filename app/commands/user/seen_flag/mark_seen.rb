class User::SeenFlag::MarkSeen
  include Mandate

  initialize_with :user, :key

  def call
    User::SeenFlag.create_or_find_by!(user:, key: key.to_s)
  end
end
