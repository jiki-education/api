class User::Destroy
  include Mandate

  initialize_with :user

  def call
    user.destroy!
  end
end
