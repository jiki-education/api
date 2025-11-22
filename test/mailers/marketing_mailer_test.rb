require "test_helper"

class MarketingMailerTest < ActionMailer::TestCase
  test "test_email sends successfully" do
    mail = MarketingMailer.test_email('test@example.com')

    assert_equal '[TEST] Marketing email from hello.jiki.io', mail.subject
    assert_equal ['hello@hello.jiki.io'], mail.from
    assert_equal ['test@example.com'], mail.to

    # Check HTML body
    assert_match 'This is a test marketing email from hello.jiki.io', mail.html_part.body.to_s

    # Check text body
    assert_match 'This is a test marketing email from hello.jiki.io', mail.text_part.body.to_s
  end

  test "test_email includes both HTML and text parts" do
    mail = MarketingMailer.test_email('test@example.com')

    assert mail.html_part.present?
    assert mail.text_part.present?
    assert_equal "text/html", mail.html_part.content_type.split(";").first
    assert_equal "text/plain", mail.text_part.content_type.split(";").first
  end

  test "test_email works in test environment" do
    # In test environment, any email should work
    assert_nothing_raised do
      MarketingMailer.test_email("test@example.com")
    end
  end

  test "test_email allows jez.walker@gmail.com in any environment" do
    # jez.walker@gmail.com should work even in production
    assert_nothing_raised do
      MarketingMailer.test_email("jez.walker@gmail.com")
    end
  end

  test "test_email does not include unsubscribe headers without user" do
    mail = MarketingMailer.test_email("test@example.com")

    # Test email without @user should not have unsubscribe headers
    assert_nil mail.header['List-Unsubscribe']
    assert_nil mail.header['List-Unsubscribe-Post']
  end
end
