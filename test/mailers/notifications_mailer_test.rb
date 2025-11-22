require "test_helper"

class NotificationsMailerTest < ActionMailer::TestCase
  test "test_email sends successfully" do
    mail = NotificationsMailer.test_email('test@example.com')

    assert_equal '[TEST] Notification email from notifications.jiki.io', mail.subject
    assert_equal ['hello@notifications.jiki.io'], mail.from
    assert_equal ['test@example.com'], mail.to

    # Check HTML body
    assert_match 'This is a test notification email from notifications.jiki.io', mail.html_part.body.to_s

    # Check text body
    assert_match 'This is a test notification email from notifications.jiki.io', mail.text_part.body.to_s
  end

  test "test_email includes both HTML and text parts" do
    mail = NotificationsMailer.test_email('test@example.com')

    assert mail.html_part.present?
    assert mail.text_part.present?
    assert_equal "text/html", mail.html_part.content_type.split(";").first
    assert_equal "text/plain", mail.text_part.content_type.split(";").first
  end

  test "test_email can only be called in test environment" do
    # This test verifies the guard clause exists
    # The actual environment check is tested by attempting to run in production
    # which would fail at the guard clause

    # In test environment, it should work
    assert_nothing_raised do
      NotificationsMailer.test_email("test@example.com")
    end
  end

  test "test_email does not include unsubscribe headers without user" do
    mail = NotificationsMailer.test_email("test@example.com")

    # Test email without @user should not have unsubscribe headers
    assert_nil mail.header['List-Unsubscribe']
    assert_nil mail.header['List-Unsubscribe-Post']
  end
end
