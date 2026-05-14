class NotificationsMailerPreview < ActionMailer::Preview
  def badge_earned
    NotificationsMailer.badge_earned(preview_user, preview_badge)
  end

  private
  def preview_user = FactoryBot.build(:user)

  def preview_badge
    FactoryBot.build(
      :member_badge,
      email_subject: "You earned a new badge!",
      email_content_markdown: "Congratulations on earning the **Member** badge. Welcome to the community!",
      email_image_url: "https://cdn.jiki.io/emails/badge-member.jpg"
    )
  end
end
