require "test_helper"

class AccountMailerTest < ActionMailer::TestCase
  test "welcome email renders with English locale" do
    user = create(:user, name: "John Doe", locale: "en")
    mail = AccountMailer.welcome(user)

    assert_equal "Welcome to Jiki!", mail.subject
    assert_equal ["hello@mail.jiki.io"], mail.from
    assert_equal [user.email], mail.to

    assert_match "Hi there,", mail.html_part.body.to_s
    assert_match "Jiki has been designed to take you from complete beginner to confident coder", mail.html_part.body.to_s
    assert_match "https://jiki.io", mail.html_part.body.to_s

    assert_match "Hi there,", mail.text_part.body.to_s
    assert_match "Jiki has been designed to take you from complete beginner to confident coder", mail.text_part.body.to_s
  end

  test "welcome email renders with Hungarian locale" do
    user = create(:user, :hungarian, name: "János Kovács", locale: "hu")
    mail = AccountMailer.welcome(user)

    assert_equal "Üdvözlünk a Jiki-nél!", mail.subject
    assert_equal ["hello@mail.jiki.io"], mail.from
    assert_equal [user.email], mail.to

    assert_match "Szia,", mail.html_part.body.to_s
    assert_match "strukturált, lineáris tanulási útvonalat kínál", mail.html_part.body.to_s
    assert_match "https://jiki.io", mail.html_part.body.to_s

    assert_match "Szia,", mail.text_part.body.to_s
    assert_match "strukturált, lineáris tanulási útvonalat kínál", mail.text_part.body.to_s
  end

  test "welcome email compiles MJML to responsive HTML" do
    user = create(:user)
    mail = AccountMailer.welcome(user)

    html_body = mail.html_part.body.to_s

    assert_match(/<table/, html_body)
    refute_match(/<mj-/, html_body)
    assert_match(/<!doctype html>/i, html_body)
    assert_match(/viewport/, html_body)
  end

  test "welcome email includes both HTML and text parts" do
    user = create(:user)
    mail = AccountMailer.welcome(user)

    assert mail.html_part.present?
    assert mail.text_part.present?
    assert_equal "text/html", mail.html_part.content_type.split(";").first
    assert_equal "text/plain", mail.text_part.content_type.split(";").first
  end

  test "welcome email defaults to English for missing locale" do
    user = build(:user, locale: nil)
    user.define_singleton_method(:locale) { nil }

    mail = AccountMailer.welcome(user)

    assert_equal "Welcome to Jiki!", mail.subject
    assert_match "Hi there,", mail.html_part.body.to_s
  end

  test "welcome email includes Jiki link" do
    user = create(:user)
    mail = AccountMailer.welcome(user)

    assert_match "https://jiki.io", mail.html_part.body.to_s
    assert_match "https://jiki.io", mail.text_part.body.to_s
  end

  test "welcome email does not include unsubscribe headers" do
    user = create(:user)
    mail = AccountMailer.welcome(user)

    assert_nil mail.header['List-Unsubscribe']
    assert_nil mail.header['List-Unsubscribe-Post']
  end
end
