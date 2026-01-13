class User::Update
  include Mandate

  initialize_with :user, :params

  def call
    # Skip reconfirmation for admin-initiated email changes
    user.skip_reconfirmation! if filtered_params[:email].present?
    user.update!(filtered_params)
    user
  end

  private
  def filtered_params
    params.slice(:email)
  end
end
