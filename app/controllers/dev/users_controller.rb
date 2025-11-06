class Dev::UsersController < Dev::BaseController
  def clear_stripe_history
    user = User.find_by!(handle: params[:handle])

    user.data.update!(
      stripe_customer_id: nil,
      stripe_subscription_id: nil,
      stripe_subscription_status: nil,
      subscription_status: 'never_subscribed',
      subscription_valid_until: nil,
      subscriptions: [],
      membership_type: "standard"
    )

    render json: {
      message: "Stripe history cleared successfully",
      user: {
        id: user.id,
        handle: user.handle,
        membership_type: user.data.membership_type,
        subscription_status: user.data.subscription_status
      }
    }, status: :ok
  end
end
