require "test_helper"

class WelcomeMailerTest < ActionMailer::TestCase
  test "welcome email renders with English locale" do
    user = create(:user, name: "John Doe", locale: "en")
    mail = WelcomeMailer.welcome(user, login_url: "http://example.com/login")

    assert_equal "Welcome to Jiki!", mail.subject
    assert_equal ["hello@mail.jiki.io"], mail.from
    assert_equal [user.email], mail.to

    # Check HTML body contains English text
    assert_match "Hi John Doe,", mail.html_part.body.to_s
    assert_match "Welcome to Jiki - your journey to learning programming starts here!", mail.html_part.body.to_s
    assert_match "Start Learning", mail.html_part.body.to_s
    assert_match "http://example.com/login", mail.html_part.body.to_s

    # Check text body
    assert_match "Hi John Doe,", mail.text_part.body.to_s
    assert_match "Welcome to Jiki - your journey to learning programming starts here!", mail.text_part.body.to_s
  end

  test "welcome email renders with Hungarian locale" do
    user = create(:user, :hungarian, name: "János Kovács", locale: "hu")
    mail = WelcomeMailer.welcome(user, login_url: "http://example.com/login")

    assert_equal "Üdvözlünk a Jiki-nél!", mail.subject
    assert_equal ["hello@mail.jiki.io"], mail.from
    assert_equal [user.email], mail.to

    # Check HTML body contains Hungarian text
    assert_match "Szia János Kovács,", mail.html_part.body.to_s
    assert_match "Üdvözlünk a Jiki-nél - itt kezdődik a programozás tanulásának útja!", mail.html_part.body.to_s
    assert_match "Kezdd el a tanulást", mail.html_part.body.to_s

    # Check text body
    assert_match "Szia János Kovács,", mail.text_part.body.to_s
    assert_match "Üdvözlünk a Jiki-nél - itt kezdődik a programozás tanulásának útja!", mail.text_part.body.to_s
  end

  test "welcome email compiles MJML to responsive HTML" do
    user = create(:user)
    mail = WelcomeMailer.welcome(user, login_url: "http://example.com/login")

    html_body = mail.html_part.body.to_s

    # Check MJML compiled to HTML (should have tables, not mj- tags)
    assert_match(/<table/, html_body)
    refute_match(/<mj-/, html_body)

    # Check responsive email structure
    assert_match(/<!doctype html>/i, html_body)
    assert_match(/viewport/, html_body)
  end

  test "welcome email includes both HTML and text parts" do
    user = create(:user)
    mail = WelcomeMailer.welcome(user, login_url: "http://example.com/login")

    assert mail.html_part.present?
    assert mail.text_part.present?
    assert_equal "text/html", mail.html_part.content_type.split(";").first
    assert_equal "text/plain", mail.text_part.content_type.split(";").first
  end

  test "welcome email defaults to English for missing locale" do
    user = build(:user, locale: nil)
    # Manually set locale to en for ApplicationMailer's with_locale helper
    user.define_singleton_method(:locale) { nil }

    mail = WelcomeMailer.welcome(user, login_url: "http://example.com/login")

    # ApplicationMailer defaults to I18n.default_locale (en) when user.locale is nil
    assert_equal "Welcome to Jiki!", mail.subject
    # HTML emails escape special characters, so we need to escape the expected value
    assert_match "Hi #{ERB::Util.html_escape(user.name)},", mail.html_part.body.to_s
  end

  test "welcome email uses user name in greeting" do
    user = create(:user, name: "Test User")
    mail = WelcomeMailer.welcome(user, login_url: "http://example.com/login")

    assert_match "Hi Test User,", mail.html_part.body.to_s
    assert_match "Hi Test User,", mail.text_part.body.to_s
  end

  test "welcome email correctly escapes user names with apostrophes in HTML" do
    user = create(:user, name: "Graig D'Amore")
    mail = WelcomeMailer.welcome(user, login_url: "http://example.com/login")

    # HTML part should escape the apostrophe as &#39;
    assert_match "Hi Graig D&#39;Amore,", mail.html_part.body.to_s
    # Text part should keep the literal apostrophe
    assert_match "Hi Graig D'Amore,", mail.text_part.body.to_s
  end

  test "welcome email includes login URL in button" do
    user = create(:user)
    login_url = "https://jiki.io/dashboard"
    mail = WelcomeMailer.welcome(user, login_url:)

    assert_match login_url, mail.html_part.body.to_s
    assert_match login_url, mail.text_part.body.to_s
  end

  test "welcome email does not include unsubscribe headers" do
    user = create(:user)
    mail = WelcomeMailer.welcome(user, login_url: "http://example.com/login")

    # Transactional emails should not have unsubscribe headers
    assert_nil mail.header['List-Unsubscribe']
    assert_nil mail.header['List-Unsubscribe-Post']
  end

  test "test_email sends successfully" do
    mail = WelcomeMailer.test_email('test@example.com')

    assert_equal '[TEST] Transactional email from mail.jiki.io', mail.subject
    assert_equal ['hello@mail.jiki.io'], mail.from
    assert_equal ['test@example.com'], mail.to

    # Check HTML body
    assert_match 'This is a test transactional email from mail.jiki.io', mail.html_part.body.to_s

    # Check text body
    assert_match 'This is a test transactional email from mail.jiki.io', mail.text_part.body.to_s
  end

  test "test_email includes both HTML and text parts" do
    mail = WelcomeMailer.test_email('test@example.com')

    assert mail.html_part.present?
    assert mail.text_part.present?
    assert_equal "text/html", mail.html_part.content_type.split(";").first
    assert_equal "text/plain", mail.text_part.content_type.split(";").first
  end

  test "test_email works in test environment" do
    # In test environment, any email should work
    assert_nothing_raised do
      WelcomeMailer.test_email("test@example.com")
    end
  end

  test "test_email allows jez.walker@gmail.com in any environment" do
    # jez.walker@gmail.com should work even in production
    assert_nothing_raised do
      WelcomeMailer.test_email("jez.walker@gmail.com")
    end
  end

  test "test_email does not include unsubscribe headers" do
    mail = WelcomeMailer.test_email("test@example.com")

    # Test email without @user should not have unsubscribe headers
    assert_nil mail.header['List-Unsubscribe']
    assert_nil mail.header['List-Unsubscribe-Post']
  end
end
