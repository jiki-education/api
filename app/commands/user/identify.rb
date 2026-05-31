class User::Identify
  include Mandate

  queue_as :analytics

  initialize_with :user

  def call
    return unless PostHog.initialized?

    PostHog.identify(
      distinct_id: user.id.to_s,
      properties: {
        membership_type: user.membership_type,
        locale: user.locale,
        signup_date: user.created_at.to_date.iso8601
      }
    )
  end
end
