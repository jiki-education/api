class User::Notification::Create
  include Mandate

  queue_as :notifications

  initialize_with :user, :type, params: Mandate::KWARGS

  def call
    existing = user.notifications.find_by(uniqueness_key: candidate.uniqueness_key)
    return existing if existing.present?

    begin
      candidate.save!
      User::Notification::SendEmail.defer(candidate, wait: 5.seconds)
      candidate
    rescue ActiveRecord::RecordNotUnique
      user.notifications.find_by(uniqueness_key: candidate.uniqueness_key)
    end
  end

  private
  memoize
  def candidate
    klass = "user/notifications/#{type}_notification".camelize.constantize
    klass.new(user:, params:)
  end
end
