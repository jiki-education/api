class Internal::FlagsController < Internal::BaseController
  def show
    render json: { flagged: current_user.flagged?(namespaced_key) }
  end

  def create
    User::Flag::Mark.(current_user, namespaced_key)
    render json: { flagged: true }
  rescue ActiveRecord::RecordInvalid => e
    render_422(:flag_invalid, errors: e.record.errors.as_json)
  end

  private
  # All FE-written flags are stored under the "client:" namespace so the FE
  # cannot read or write server-controlled flags (e.g. email send tracking).
  def namespaced_key = "client:#{params[:key]}"
end
