class Internal::EventsController < Internal::BaseController
  ALLOWED_EVENTS = {
    "premium_feature_blocked" => %w[feature context_type context_id context_slug context_uuid],
    "premium_modal_shown" => %w[trigger context_type context_id context_slug context_uuid]
  }.freeze

  CONTEXT_MODELS = {
    "lesson" => Lesson,
    "project" => Project
  }.freeze

  def create
    return render_422(:invalid_event) unless ALLOWED_EVENTS.key?(params[:event])

    Analytics::TrackEvent.defer(
      current_user,
      params[:event],
      properties: enriched_properties
    )

    head :no_content
  end

  private
  def enriched_properties
    props = permitted_properties
    type = props["context_type"]
    slug = props["context_slug"]
    return props unless type && slug

    model = CONTEXT_MODELS[type]
    entity = model&.find_by(slug:)
    entity ? props.merge("context_id" => entity.id) : props
  end

  def permitted_properties
    allowed = ALLOWED_EVENTS.fetch(params[:event])
    params.fetch(:properties, {}).permit(*allowed).to_h
  end
end
