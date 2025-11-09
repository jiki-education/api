class User::Update
  include Mandate

  initialize_with :user, :params

  def call
    user.update!(filtered_params)
    user
  end

  private
  def filtered_params
    params.slice(:email)
  end
end
