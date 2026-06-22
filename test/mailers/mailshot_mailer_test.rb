require "test_helper"

class MailshotMailerTest < ActionMailer::TestCase
  test "renders subject, recipient, from address and body" do
    user = create(:user)
    mailshot = create(:mailshot, subject: "Monthly news", body_markdown: "## Heading")

    mail = MailshotMailer.send_mailshot(user, mailshot)

    assert_equal "Monthly news", mail.subject
    assert_equal [user.email], mail.to
    assert_equal ["hello@hello.jiki.io"], mail.from
    assert_match "Heading", mail.html_part.body.to_s
    assert_match "Heading", mail.text_part.body.to_s
  end

  test "sets one-click unsubscribe headers for the newsletters preference" do
    user = create(:user)
    mailshot = create(:mailshot)

    mail = MailshotMailer.send_mailshot(user, mailshot)

    assert_match "key=newsletters", mail.header["List-Unsubscribe"].to_s
    assert_equal "List-Unsubscribe=One-Click", mail.header["List-Unsubscribe-Post"].to_s
  end

  test "does not send when the user has opted out" do
    user = create(:user)
    user.data.update!(receive_newsletters: false)
    mailshot = create(:mailshot)

    mail = MailshotMailer.send_mailshot(user, mailshot)

    assert_nil mail.to
  end

  test "force: true sends even when the user has opted out" do
    user = create(:user)
    user.data.update!(receive_newsletters: false)
    mailshot = create(:mailshot)

    mail = MailshotMailer.send_mailshot(user, mailshot, force: true)

    assert_equal [user.email], mail.to
  end
end
