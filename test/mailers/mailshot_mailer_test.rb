require "test_helper"

class MailshotMailerTest < ActionMailer::TestCase
  test "renders subject, recipient, from and body" do
    user = create(:user)
    mailshot = create(:mailshot, subject: "Monthly news", body_markdown: "## Heading")

    mail = MailshotMailer.send_mailshot(user, mailshot)

    assert_equal "Monthly news", mail.subject
    assert_equal [user.email], mail.to
    assert_equal ["hello@hello.jiki.io"], mail.from
    assert_equal "Jeremy Walker <hello@hello.jiki.io>", mail[:from].value
    assert_match "Heading", mail.html_part.body.to_s
    assert_match "Heading", mail.text_part.body.to_s
  end

  test "uses preview_text as the preheader" do
    user = create(:user)
    mailshot = create(:mailshot, subject: "Monthly news", preview_text: "Three new exercises inside")

    html = MailshotMailer.send_mailshot(user, mailshot).html_part.body.to_s

    assert_match "Three new exercises inside", html
  end

  test "points one-click unsubscribe at the API endpoint for the newsletters preference" do
    user = create(:user)
    mailshot = create(:mailshot)

    mail = MailshotMailer.send_mailshot(user, mailshot)

    header = mail.header["List-Unsubscribe"].to_s
    assert_match "#{Jiki.config.api_base_url}/auth/unsubscribe/#{user.unsubscribe_token}", header
    assert_match "key=newsletters", header
    assert_equal "List-Unsubscribe=One-Click", mail.header["List-Unsubscribe-Post"].to_s
  end

  test "does not send when the user has opted out" do
    user = create(:user)
    user.data.update!(receive_newsletters: false)
    mailshot = create(:mailshot)

    mail = MailshotMailer.send_mailshot(user, mailshot)

    assert_nil mail.to
  end

  test "does not send when the recipient's email has bounced" do
    user = create(:user)
    user.data.update!(email_bounced_at: Time.current)
    mailshot = create(:mailshot)

    mail = MailshotMailer.send_mailshot(user, mailshot)

    assert_nil mail.to
  end
end
