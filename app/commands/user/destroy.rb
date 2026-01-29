class User::Destroy
  include Mandate

  initialize_with :user

  def call
    Stripe::CancelSubscription.(user, cancel_immediately: true)
    user.destroy!
  end
end
