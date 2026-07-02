class User::Bootstrap
  include Mandate

  initialize_with :user, :provider, attribution: nil, country_code: nil, accept_language: nil

  def call
    set_country_code!
    set_locales!
    send_welcome_email!
    enroll_in_course!
    award_member_badge!
    award_beta_user_badge!
    attribute!
    track!
  end

  private
  def set_country_code!
    code = country_code.to_s.upcase[0, 2]
    return if code.blank? || code == "XX"

    user.data.update_column(:country_code, code)
  end

  def set_locales! = User::UpdateLocales.(user, accept_language)

  # Email-signup users are unconfirmed at this point — they'll get the welcome
  # email via User#after_confirmation. OAuth users are pre-confirmed so we send
  # it here. The command is idempotent, so this is safe either way.
  def send_welcome_email!
    return unless user.confirmed?

    User::SendWelcomeEmail.(user)
  end

  def enroll_in_course!
    UserCourse::Enroll.(user, course)
  end

  def award_member_badge!
    AwardBadgeJob.perform_later(user, 'member')
  end

  def award_beta_user_badge!
    AwardBadgeJob.perform_later(user, 'beta_user')
  end

  def attribute!
    return if attribution.blank?

    user.data.update!(signup_attribution: attribution)
  end

  def track!
    User::Identify.defer(user)
    Analytics::TrackEvent.defer(
      user,
      "user_signed_up",
      properties: { provider: }.merge(attribution || {}).merge(attribution_properties)
    )
  end

  # Map our signup attribution onto PostHog's reserved property names so its
  # built-in attribution features work: $referrer/$referring_domain/$current_url
  # drive Channel Type classification on the event, and $set_once writes the
  # $initial_* person properties used for first-touch attribution breakdowns.
  memoize
  def attribution_properties
    return {} if attribution.blank?

    {
      "$referrer": referrer,
      "$referring_domain": referring_domain,
      "$current_url": landing_url,
      "$set_once": {
        "$initial_referrer": referrer,
        "$initial_referring_domain": referring_domain,
        "$initial_current_url": landing_url,
        "$initial_utm_source": attribution["utm_source"],
        "$initial_utm_medium": attribution["utm_medium"],
        "$initial_utm_campaign": attribution["utm_campaign"]
      }.compact
    }.compact
  end

  # PostHog uses the literal value "$direct" to mean "no referrer".
  memoize
  def referrer = attribution["referrer"].presence || "$direct"

  memoize
  def referring_domain
    return "$direct" if attribution["referrer"].blank?

    URI.parse(attribution["referrer"]).host || "$direct"
  rescue URI::InvalidURIError
    "$direct"
  end

  memoize
  def landing_url
    return nil if attribution["landing_path"].blank?

    URI.join(Jiki.config.frontend_base_url, attribution["landing_path"]).to_s
  rescue URI::InvalidURIError
    nil
  end

  memoize
  def course = Course.find_by!(slug: "coding-fundamentals")
end
