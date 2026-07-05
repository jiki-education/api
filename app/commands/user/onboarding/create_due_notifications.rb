class User::Onboarding::CreateDueNotifications
  include Mandate

  queue_as :background

  # Day after the anchor → notification kind.
  # Gated on confirmed_at being present at send time.
  EMAILS = {
    1 => :onboarding_overview,
    2 => :onboarding_coding,
    3 => :onboarding_building,
    4 => :onboarding_premium,
    5 => :onboarding_community
  }.freeze

  # Safety window — if the cron job doesn't run for a while, we don't miss
  # users. Anyone anchored between N days ago and N+SAFETY_OFFSET days ago
  # is still eligible. Idempotency comes from User::Notification's uniqueness
  # key, so running this multiple times is safe.
  SAFETY_OFFSET_IN_DAYS = 1

  PREMIUM_KIND = :onboarding_premium

  # Users who existed before launch never signed up "recently", so anchoring on
  # created_at would mean they never get the cadence. Instead anchor them on the
  # launch date (keeping their created_at time-of-day, so the backfilled cohort
  # spreads across the day rather than all firing at midnight). Post-launch
  # signups have created_at >= LAUNCH_DATE, so GREATEST leaves them on created_at.
  # Once every pre-launch user has passed day 6 this becomes a no-op and the
  # constant + GREATEST can be removed.
  LAUNCH_DATE = Date.new(2026, 7, 5)
  ANCHOR_SQL = "GREATEST(created_at, CAST(:launch AS date) + created_at::time)".freeze

  def call
    EMAILS.each do |day, kind|
      due_users_for(day).find_each do |user|
        next if kind == PREMIUM_KIND && user.premium?

        User::Notification::Create.(user, kind)
      rescue StandardError => e
        Sentry.capture_exception(e) if defined?(Sentry)
      end
    end
  end

  private
  def due_users_for(day)
    # Preload :data so the premium? check below (delegated to User::Data)
    # doesn't fire a query per user.
    User.includes(:data).
      where.not(confirmed_at: nil).
      where("#{ANCHOR_SQL} < :from", launch: LAUNCH_DATE, from: Time.current - day.days).
      where("#{ANCHOR_SQL} >= :to", launch: LAUNCH_DATE, to: Time.current - (day + SAFETY_OFFSET_IN_DAYS).days)
  end
end
