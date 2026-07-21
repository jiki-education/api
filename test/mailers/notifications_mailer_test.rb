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

  test "badge_earned renders English chrome and footer by default" do
    mail = NotificationsMailer.badge_earned(@user, @badge)

    html = mail.html_part.body.to_s
    text = mail.text_part.body.to_s

    # Greeting and sign-off
    assert_match "Hi there,", html
    assert_match "Cheers,", html
    assert_match "Hi there,", text
    assert_match "Jeremy & Team", text

    # Preview
    assert_match "You&#39;ve earned a new badge!", html

    # Shared footer chrome
    assert_match "You are receiving this email because you have an account at", html
    assert_match "update your preferences", html
    assert_match "unsubscribe", html
  end

  test "badge_earned renders Hungarian chrome and footer for hu user" do
    user = create(:user, :hungarian)

    mail = NotificationsMailer.badge_earned(user, @badge)

    html = mail.html_part.body.to_s
    text = mail.text_part.body.to_s

    # Greeting and sign-off
    assert_match "Szia,", html
    assert_match "Üdv,", html
    assert_match "Jeremy és a csapat", text

    # Preview
    assert_match "Új jelvényt szereztél!", html

    # Shared footer chrome (Hungarian)
    assert_match "Ezt az e-mailt azért kapod", html
    assert_match "módosítsd a beállításaidat", html
    assert_match "iratkozz le", html
  end

  test "badge_earned sets @header_image to badge-earned.jpg" do
    mail = NotificationsMailer.badge_earned(@user, @badge)

    assert_match "static/emails/badge-earned.jpg", mail.html_part.body.to_s
  end
end
