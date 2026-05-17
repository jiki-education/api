class Analytics::TrackEvent
  include Mandate

  queue_as :analytics

  initialize_with :user, :event, properties: {}

  def call
    PostHog.capture(
      distinct_id: user.id.to_s,
      event: event,
      properties: properties.merge(default_properties)
    )
  end

  private
  def default_properties
    {
      membership_type: user.membership_type,
      locale: user.locale
    }
  end
end
