class User::Destroy
  include Mandate

  initialize_with :user

  def call
    # Clear the circular references before destroying
    # UserCourses can have a current_user_level_id pointing to a UserLevel,
    # which has a user_id pointing back to the User.
    # We must clear these before destroying to avoid FK constraint violations.
    user.user_courses.update_all(current_user_level_id: nil)
    user.destroy!
  end
end
