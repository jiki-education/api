class Internal::EventsController < Internal::BaseController
  ALLOWED_EVENTS = {
    "premium_feature_blocked" => %w[feature context_type context_id context_slug context_uuid],
    "premium_modal_shown" => %w[trigger context_type context_id context_slug context_uuid],

    # The checkout funnel after `checkout_started`, which the API tracks itself
    # when it creates the session. A purchase ends in `upgraded_to_premium`.
    "checkout_submitted" => %w[trigger],
    "checkout_failed" => %w[trigger error_code decline_code],
    "checkout_closed" => %w[trigger]
  }.freeze

  ABANDONED_CHECKOUT_EMAIL_DELAY = 30.minutes

  CONTEXT_MODELS = {
    "lesson" => Lesson,
    "challenge" => Challenge
  }.freeze

  def create
    return render_422(:invalid_event) unless ALLOWED_EVENTS.key?(params[:event])

    Analytics::TrackEvent.defer(
      current_user,
      params[:event],
      properties: enriched_properties
    )
    schedule_abandoned_checkout_email! if params[:event] == "checkout_closed"

    head :no_content
  end

  private
  def schedule_abandoned_checkout_email!
    User::SendAbandonedCheckoutEmail.defer(current_user, wait: ABANDONED_CHECKOUT_EMAIL_DELAY)
  end

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
