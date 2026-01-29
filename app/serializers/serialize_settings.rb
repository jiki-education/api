class SerializeSettings
  include Mandate

  initialize_with :user

  def call
    {
      name: user.name,
      handle: user.handle,
      email: user.email,
      unconfirmed_email: user.unconfirmed_email,
      email_confirmed: user.confirmed?,
      locale: user.locale,
      receive_product_updates: user.data.receive_product_updates,
      receive_event_emails: user.data.receive_event_emails,
      receive_milestone_emails: user.data.receive_milestone_emails,
      receive_activity_emails: user.data.receive_activity_emails,
      streaks_enabled: user.data.streaks_enabled
    }
  end
end
