class Analytics::TrackEvent
  include Mandate

  queue_as :analytics

  initialize_with :user, :event, properties: {}, user_ip: nil, user_agent: nil

  # Current is request-scoped and unavailable in the background job,
  # so materialise the user's IP and user agent into the job arguments at
  # defer time. The guards preserve already-materialised values when a job
  # re-defers itself (e.g. via requeue_job!).
  def self.defer(*args, **kwargs)
    kwargs[:user_ip] = Current.user_ip unless kwargs.key?(:user_ip)
    kwargs[:user_agent] = Current.user_agent unless kwargs.key?(:user_agent)
    super(*args, **kwargs)
  end

  def call
    return unless PostHog.initialized?

    PostHog.capture(
      distinct_id: user.id.to_s,
      event: event,
      properties: properties.merge(default_properties).merge(derived_properties)
    )
  end

  private
  def default_properties
    {
      membership_type: user.membership_type,
      locale: user.locale
    }
  end

  def derived_properties
    geoip_properties.merge(user_agent_properties)
  end

  # With a real user IP, PostHog's GeoIP transformation resolves it into
  # location data. Without one, disable GeoIP for this event so PostHog
  # doesn't resolve the location of our servers instead.
  def geoip_properties
    return { "$geoip_disable": true } unless user_ip.present?

    { "$ip": user_ip }
  end

  # PostHog's "User Agent Populator" transformation parses $useragent into
  # $browser, $browser_version, $os, $device and $device_type. It must be
  # enabled in the PostHog project (Data pipeline → Transformations).
  def user_agent_properties
    return {} if user_agent.blank?

    { "$useragent": user_agent }
  end
end
