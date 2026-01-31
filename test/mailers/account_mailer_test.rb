require "test_helper"

class AccountMailerTest < ActionMailer::TestCase
  test "welcome email renders with English locale" do
    user = create(:user, name: "John Doe", locale: "en")
    mail = AccountMailer.welcome(user, login_url: "http://example.com/login")

    assert_equal "Welcome to Jiki!", mail.subject
    assert_equal ["hello@mail.jiki.io"], mail.from
    assert_equal [user.email], mail.to

    assert_match "Hi John Doe,", mail.html_part.body.to_s
    assert_match "Jiki provides a structured, linear learning path", mail.html_part.body.to_s
    assert_match "Start Learning", mail.html_part.body.to_s
    assert_match "http://example.com/login", mail.html_part.body.to_s

    assert_match "Hi John Doe,", mail.text_part.body.to_s
    assert_match "Jiki provides a structured, linear learning path", mail.text_part.body.to_s
  end

  test "welcome email renders with Hungarian locale" do
    user = create(:user, :hungarian, name: "János Kovács", locale: "hu")
    mail = AccountMailer.welcome(user, login_url: "http://example.com/login")

    assert_equal "Üdvözlünk a Jiki-nél!", mail.subject
    assert_equal ["hello@mail.jiki.io"], mail.from
    assert_equal [user.email], mail.to

    assert_match "Szia János Kovács,", mail.html_part.body.to_s
    assert_match "A Jiki strukturált, lineáris tanulási útvonalat kínál", mail.html_part.body.to_s
    assert_match "Kezdd el a tanulást", mail.html_part.body.to_s

    assert_match "Szia János Kovács,", mail.text_part.body.to_s
    assert_match "A Jiki strukturált, lineáris tanulási útvonalat kínál", mail.text_part.body.to_s
  end

  test "welcome email compiles MJML to responsive HTML" do
    user = create(:user)
    mail = AccountMailer.welcome(user, login_url: "http://example.com/login")

    html_body = mail.html_part.body.to_s

    assert_match(/<table/, html_body)
    refute_match(/<mj-/, html_body)
    assert_match(/<!doctype html>/i, html_body)
    assert_match(/viewport/, html_body)
  end

  test "welcome email includes both HTML and text parts" do
    user = create(:user)
    mail = AccountMailer.welcome(user, login_url: "http://example.com/login")

    assert mail.html_part.present?
    assert mail.text_part.present?
    assert_equal "text/html", mail.html_part.content_type.split(";").first
    assert_equal "text/plain", mail.text_part.content_type.split(";").first
  end

  test "welcome email defaults to English for missing locale" do
    user = build(:user, locale: nil)
    user.define_singleton_method(:locale) { nil }

    mail = AccountMailer.welcome(user, login_url: "http://example.com/login")

    assert_equal "Welcome to Jiki!", mail.subject
    assert_match "Hi #{ERB::Util.html_escape(user.name)},", mail.html_part.body.to_s
  end

  test "welcome email uses user name in greeting" do
    user = create(:user, name: "Test User")
    mail = AccountMailer.welcome(user, login_url: "http://example.com/login")

    assert_match "Hi Test User,", mail.html_part.body.to_s
    assert_match "Hi Test User,", mail.text_part.body.to_s
  end

  test "welcome email correctly escapes user names with apostrophes in HTML" do
    user = create(:user, name: "Graig D'Amore")
    mail = AccountMailer.welcome(user, login_url: "http://example.com/login")

    assert_match "Hi Graig D&#39;Amore,", mail.html_part.body.to_s
    assert_match "Hi Graig D'Amore,", mail.text_part.body.to_s
  end

  test "welcome email includes login URL in button" do
    user = create(:user)
    login_url = "https://jiki.io/dashboard"
    mail = AccountMailer.welcome(user, login_url:)

    assert_match login_url, mail.html_part.body.to_s
    assert_match login_url, mail.text_part.body.to_s
  end

  test "welcome email does not include unsubscribe headers" do
    user = create(:user)
    mail = AccountMailer.welcome(user, login_url: "http://example.com/login")

    assert_nil mail.header['List-Unsubscribe']
    assert_nil mail.header['List-Unsubscribe-Post']
  end
end
