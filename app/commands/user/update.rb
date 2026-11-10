class User::Update
  include Mandate

  initialize_with :user, :params

  def call
    # Skip reconfirmation for admin-initiated email changes
    user.skip_reconfirmation! if filtered_params[:email].present?
    user.update!(filtered_params)

    # Pass no IP, because Current.user_ip is the admin's IP here, not the user's.
    User::Identify.defer(user, user_ip: nil) if user.data.saved_change_to_internal?
    user
  end

  private
  def filtered_params
    params.slice(:email, :internal)
  end
end
