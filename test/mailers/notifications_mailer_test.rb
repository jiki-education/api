require "test_helper"

class NotificationsMailerTest < ActionMailer::TestCase
  def setup
    @user = create(:user)
    @badge = create(:member_badge)
    @badge.stubs(:content_for_locale).returns(
      name: "Member",
      description: "Joined Jiki",
      fun_fact: "Welcome!",
      email_subject: "You earned a badge!",
      email_content_markdown: "Congrats on earning the Member badge."
    )
    @badge.stubs(:email_image_url).returns("https://cdn.jiki.io/emails/badge.jpg")
  end

  test "badge_earned email renders correctly" do
    mail = NotificationsMailer.badge_earned(@user, @badge)

    assert_equal "You earned a badge!", mail.subject
    assert_equal [@user.email], mail.to
    assert mail.html_part.body.to_s.present?
  end

  test "badge_earned sets @header_image to badge-earned.jpg" do
    mail = NotificationsMailer.badge_earned(@user, @badge)

    assert_match "static/emails/badge-earned.jpg", mail.html_part.body.to_s
  end
end
