class Internal::EventsController < Internal::BaseController
  ALLOWED_EVENTS = {
    "premium_feature_blocked" => %w[feature context_type context_id],
    "premium_modal_shown" => %w[trigger context_type context_id]
  }.freeze

  def create
    return render_422(:invalid_event) unless ALLOWED_EVENTS.key?(params[:event])

    Analytics::TrackEvent.defer(
      current_user,
      params[:event],
      properties: permitted_properties
    )

    head :no_content
  end

  private
  def permitted_properties
    allowed = ALLOWED_EVENTS.fetch(params[:event])
    params.fetch(:properties, {}).permit(*allowed).to_h
  end
end
