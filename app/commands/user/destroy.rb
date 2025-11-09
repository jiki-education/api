class User::Destroy
  include Mandate

  initialize_with :user

  def call
    # Clear the circular reference before destroying
    # Users can have a current_user_level_id pointing to a UserLevel,
    # which has a user_id pointing back to the User.
    # We must clear this before destroying to avoid FK constraint violations.
    user.update_column(:current_user_level_id, nil) if user.current_user_level_id.present?
    user.destroy!
  end
end
