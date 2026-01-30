# Marketing emails sent via hello.jiki.io
# - Monthly newsletters
# - Feature announcements
# - Event announcements
#
# Users can unsubscribe via newsletters or event_emails preferences.

class MarketingMailer < ApplicationMailer
  self.email_category = :marketing

  # Example: Monthly newsletter
  # def monthly_newsletter(user)
  #   with_locale(user) do
  #     mail_to_user(
  #       user,
  #       unsubscribe_key: :newsletters,
  #       to: user.email,
  #       subject: "What's new at Jiki - #{Date.current.strftime('%B %Y')}"
  #     )
  #   end
  # end

  # Example: Event announcement
  # def event_announcement(user, event)
  #   with_locale(user) do
  #     @event = event
  #
  #     mail_to_user(
  #       user,
  #       unsubscribe_key: :event_emails,
  #       to: user.email,
  #       subject: "Join us: #{event.title}"
  #     )
  #   end
  # end
end
