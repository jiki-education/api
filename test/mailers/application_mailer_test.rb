require "test_helper"

class ApplicationMailerTest < ActionMailer::TestCase
  # Test mailer class to test the protected mail_template_to_user method
  class TestMailer < ApplicationMailer
    self.email_category = :transactional

    def test_template_email(user, template_type, template_key, context = {})
      mail_template_to_user(user, template_type, template_key, context:)
    end
  end

  test "renders email with Liquid variables in subject and body" do
    user = create(:user, name: "Alice Smith", email: "alice@example.com", locale: "en")
    level = create(:level, title: "Ruby Basics", slug: "ruby-basics")
    create(:email_template, type: :level_completion, slug: "ruby-basics", locale: "en")

    mail = TestMailer.test_template_email(
      user,
      :level_completion,
      "ruby-basics",
      { level: LevelDrop.new(level) }
    )

    assert_equal "Congratulations Alice Smith!", mail.subject
    assert_match "Congratulations, Alice Smith!", mail.html_part.body.to_s
    assert_match "You completed Ruby Basics!", mail.html_part.body.to_s
    assert_match "Congratulations, Alice Smith! You completed Ruby Basics!", mail.text_part.body.to_s
  end

  test "automatically injects user into Liquid context" do
    user = create(:user, name: "Bob Jones", email: "bob@example.com", locale: "en")
    level = create(:level, title: "Python Intro", slug: "python-intro")
    create(:email_template, type: :level_completion, slug: "python-intro", locale: "en")

    mail = TestMailer.test_template_email(
      user,
      :level_completion,
      "python-intro",
      { level: LevelDrop.new(level) }
    )

    # User name should be rendered from the user Drop
    assert_match "Bob Jones", mail.subject
    assert_match "Bob Jones", mail.html_part.body.to_s
    assert_match "Bob Jones", mail.text_part.body.to_s
  end

  test "passes custom context variables to Liquid" do
    user = create(:user, name: "Carol", locale: "en")
    level = create(:level, title: "JavaScript Fundamentals", slug: "js-fundamentals")
    create(:email_template, type: :level_completion, slug: "js-fundamentals", locale: "en")

    mail = TestMailer.test_template_email(
      user,
      :level_completion,
      "js-fundamentals",
      { level: LevelDrop.new(level) }
    )

    # Level should be accessible in template via custom context
    assert_match "JavaScript Fundamentals", mail.html_part.body.to_s
    assert_match "JavaScript Fundamentals", mail.text_part.body.to_s
  end

  test "respects user locale for email rendering" do
    user = create(:user, :hungarian, name: "János", locale: "hu")
    level = create(:level, title: "Ruby Alapok", slug: "ruby-basics")
    create(:email_template, :hungarian, type: :level_completion, slug: "ruby-basics", locale: "hu")

    mail = TestMailer.test_template_email(
      user,
      :level_completion,
      "ruby-basics",
      { level: LevelDrop.new(level) }
    )

    assert_equal "Gratulálunk János!", mail.subject
    assert_match "Gratulálunk, János!", mail.html_part.body.to_s
    assert_match "Teljesítetted: Ruby Alapok!", mail.html_part.body.to_s
  end

  test "compiles MJML to HTML using MRML" do
    user = create(:user, locale: "en")
    level = create(:level, slug: "level-1")
    create(:email_template, slug: "level-1", locale: "en")

    mail = TestMailer.test_template_email(
      user,
      :level_completion,
      "level-1",
      { level: LevelDrop.new(level) }
    )

    html_body = mail.html_part.body.to_s

    # MJML should be compiled to HTML tables (not mj- tags)
    assert_match(/<table/, html_body)
    refute_match(/<mj-/, html_body)

    # Should have responsive email structure
    assert_match(/<!doctype html>/i, html_body)
    assert_match(/viewport/, html_body)
  end

  test "uses MJML templates stored in database" do
    user = create(:user, name: "Dave", locale: "en")
    level = create(:level, title: "CSS Basics", slug: "css-basics")

    # Templates in database use MJML syntax (e.g., <mj-section>)
    create(:email_template, slug: "css-basics", locale: "en")

    mail = TestMailer.test_template_email(
      user,
      :level_completion,
      "css-basics",
      { level: LevelDrop.new(level) }
    )

    html_body = mail.html_part.body.to_s

    # MJML should be compiled to HTML
    assert_match "Congratulations, Dave!", html_body
    assert_match "CSS Basics", html_body
    refute_match(/<mj-/, html_body) # No raw MJML tags in final output
  end

  test "sends multipart email with HTML and text parts" do
    user = create(:user, locale: "en")
    level = create(:level, slug: "level-1")
    create(:email_template, slug: "level-1", locale: "en")

    mail = TestMailer.test_template_email(
      user,
      :level_completion,
      "level-1",
      { level: LevelDrop.new(level) }
    )

    assert mail.html_part.present?, "Email should have HTML part"
    assert mail.text_part.present?, "Email should have text part"
    assert_equal "text/html", mail.html_part.content_type.split(";").first
    assert_equal "text/plain", mail.text_part.content_type.split(";").first
  end

  test "returns nil when template not found" do
    user = create(:user, locale: "en")

    mail = TestMailer.test_template_email(
      user,
      :level_completion,
      "nonexistent-level",
      {}
    ).message

    # ActionMailer returns a NullMail object when mail() is not called
    assert_instance_of ActionMailer::Base::NullMail, mail
  end

  test "sets correct email metadata" do
    user = create(:user, name: "Eve", email: "eve@example.com", locale: "en")
    level = create(:level, slug: "level-1")
    create(:email_template, slug: "level-1", locale: "en")

    mail = TestMailer.test_template_email(
      user,
      :level_completion,
      "level-1",
      { level: LevelDrop.new(level) }
    )

    assert_equal ["hello@mail.jiki.io"], mail.from
    assert_equal ["eve@example.com"], mail.to
    assert_equal "Congratulations Eve!", mail.subject
  end

  test "handles empty context hash" do
    user = create(:user, name: "Frank", locale: "en")

    # Create template without level variable
    create(:email_template,
      slug: "simple",
      locale: "en",
      subject: "Hello {{ user.name }}",
      body_mjml: "<mj-section><mj-column><mj-text>Hi {{ user.name }}</mj-text></mj-column></mj-section>",
      body_text: "Hi {{ user.name }}")

    mail = TestMailer.test_template_email(
      user,
      :level_completion,
      "simple",
      {} # Empty context
    )

    assert_equal "Hello Frank", mail.subject
    assert_match "Hi Frank", mail.html_part.body.to_s
  end

  test "converts symbol keys to strings for Liquid context" do
    user = create(:user, locale: "en")
    level = create(:level, title: "Test Level", slug: "test")
    create(:email_template, slug: "test", locale: "en")

    # Context passed with symbol key
    mail = TestMailer.test_template_email(
      user,
      :level_completion,
      "test",
      { level: LevelDrop.new(level) } # Symbol key
    )

    # Should work - level accessible as string in Liquid
    assert_match "Test Level", mail.html_part.body.to_s
  end
end
