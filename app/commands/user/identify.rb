class User::Identify
  include Mandate

  queue_as :analytics

  initialize_with :user, user_ip: nil

  # Current is request-scoped and unavailable in the background job,
  # so materialise the user's IP into the job arguments at defer time.
  # The guard preserves an already-materialised IP when a job re-defers
  # itself (e.g. via requeue_job!).
  def self.defer(*args, **kwargs)
    kwargs[:user_ip] = Current.user_ip unless kwargs.key?(:user_ip)
    super(*args, **kwargs)
  end

  def call
    return unless PostHog.initialized?

    PostHog.identify(
      distinct_id: user.id.to_s,
      properties: {
        username: user.handle,
        membership_type: user.membership_type,
        locale: user.locale,
        signup_date: user.created_at.to_date.iso8601
      }.merge(geoip_properties)
    )
  end

  private
  # With a real user IP, PostHog's GeoIP transformation resolves it into
  # location data. Without one, disable GeoIP for this event so PostHog
  # doesn't resolve the location of our servers instead.
  def geoip_properties
    return { "$geoip_disable": true } unless user_ip.present?

    { "$ip": user_ip }
  end
end
