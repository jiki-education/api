class User::Destroy
  include Mandate

  initialize_with :user

  def call
    Stripe::CancelSubscriptionImmediately.(user)
    user.destroy!
  end
end
