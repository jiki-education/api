class Internal::PaymentsController < Internal::BaseController
  def index
    payments = current_user.payments.most_recent_first
    render json: { payments: SerializePayments.(payments) }
  end
end
