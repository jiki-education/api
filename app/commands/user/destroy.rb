class User::Destroy
  include Mandate

  initialize_with :user

  def call
    raise RootAdminProtectedError if user.root_admin?

    Stripe::CancelSubscription.(user, cancel_immediately: true)
    user.destroy!
  end
end
