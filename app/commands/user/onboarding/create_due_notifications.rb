class User::Onboarding::CreateDueNotifications
  include Mandate

  queue_as :background

  # Day after signup → notification kind.
  # Anchored on User#created_at, gated on confirmed_at being present at send time.
  EMAILS = {
    0 => :onboarding_overview,
    1 => :onboarding_coding,
    2 => :onboarding_building,
    4 => :onboarding_backstory,
    6 => :onboarding_premium,
    8 => :onboarding_community
  }.freeze

  # Safety window — if the cron job doesn't run for a while, we don't miss
  # users. Anyone created between N days ago and N+SAFETY_OFFSET days ago
  # is still eligible. Idempotency comes from User::Notification's uniqueness
  # key, so running this multiple times is safe.
  SAFETY_OFFSET_IN_DAYS = 1

  PREMIUM_KIND = :onboarding_premium

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
    User.where.not(confirmed_at: nil).
      where("created_at < ?", Time.current - day.days).
      where("created_at >= ?", Time.current - (day + SAFETY_OFFSET_IN_DAYS).days)
  end
end
