class Dev::UsersController < Dev::BaseController
  def clear_stripe_history
    user = User.find(params[:id])

    user.data.update!(
      stripe_customer_id: nil,
      stripe_subscription_id: nil,
      stripe_subscription_status: nil,
      subscription_current_period_end: nil,
      payment_failed_at: nil,
      membership_type: "standard"
    )

    render json: {
      message: "Stripe history cleared successfully",
      user: {
        id: user.id,
        handle: user.handle,
        membership_type: user.data.membership_type
      }
    }, status: :ok
  end
end
