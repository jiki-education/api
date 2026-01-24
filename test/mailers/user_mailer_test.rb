require "test_helper"

class UserMailerTest < ActionMailer::TestCase
  # welcome_to_premium tests
  test "welcome_to_premium email renders correctly" do
    user = create(:user, name: "John Doe")
    mail = UserMailer.welcome_to_premium(user)

    assert_equal "Welcome to Jiki Premium!", mail.subject
    assert_equal ["hello@mail.jiki.io"], mail.from
    assert_equal [user.email], mail.to

    assert_match "Hi John Doe!", mail.html_part.body.to_s
    assert_match "Thank you for subscribing to Jiki Premium", mail.html_part.body.to_s

    assert_match "Hi John Doe!", mail.text_part.body.to_s
    assert_match "Thank you for subscribing to Jiki Premium", mail.text_part.body.to_s
  end

  test "welcome_to_premium email includes both HTML and text parts" do
    user = create(:user)
    mail = UserMailer.welcome_to_premium(user)

    assert mail.html_part.present?
    assert mail.text_part.present?
    assert_equal "text/html", mail.html_part.content_type.split(";").first
    assert_equal "text/plain", mail.text_part.content_type.split(";").first
  end

  test "welcome_to_premium email compiles MJML to responsive HTML" do
    user = create(:user)
    mail = UserMailer.welcome_to_premium(user)

    html_body = mail.html_part.body.to_s

    # Check MJML compiled to HTML (should have tables, not mj- tags)
    assert_match(/<table/, html_body)
    refute_match(/<mj-/, html_body)
  end

  # welcome_to_max tests
  test "welcome_to_max email renders correctly" do
    user = create(:user, name: "John Doe")
    mail = UserMailer.welcome_to_max(user)

    assert_equal "Welcome to Jiki Max!", mail.subject
    assert_equal ["hello@mail.jiki.io"], mail.from
    assert_equal [user.email], mail.to

    assert_match "Hi John Doe!", mail.html_part.body.to_s
    assert_match "Thank you for subscribing to Jiki Max", mail.html_part.body.to_s

    assert_match "Hi John Doe!", mail.text_part.body.to_s
    assert_match "Thank you for subscribing to Jiki Max", mail.text_part.body.to_s
  end

  test "welcome_to_max email includes both HTML and text parts" do
    user = create(:user)
    mail = UserMailer.welcome_to_max(user)

    assert mail.html_part.present?
    assert mail.text_part.present?
    assert_equal "text/html", mail.html_part.content_type.split(";").first
    assert_equal "text/plain", mail.text_part.content_type.split(";").first
  end

  test "welcome_to_max email compiles MJML to responsive HTML" do
    user = create(:user)
    mail = UserMailer.welcome_to_max(user)

    html_body = mail.html_part.body.to_s

    # Check MJML compiled to HTML (should have tables, not mj- tags)
    assert_match(/<table/, html_body)
    refute_match(/<mj-/, html_body)
  end

  # subscription_ended tests
  test "subscription_ended email renders correctly" do
    user = create(:user, name: "John Doe")
    mail = UserMailer.subscription_ended(user)

    assert_equal "Your Jiki subscription has ended", mail.subject
    assert_equal ["hello@mail.jiki.io"], mail.from
    assert_equal [user.email], mail.to

    assert_match "Hi John Doe!", mail.html_part.body.to_s
    assert_match "Your subscription has ended", mail.html_part.body.to_s

    assert_match "Hi John Doe!", mail.text_part.body.to_s
    assert_match "Your subscription has ended", mail.text_part.body.to_s
  end

  test "subscription_ended email includes both HTML and text parts" do
    user = create(:user)
    mail = UserMailer.subscription_ended(user)

    assert mail.html_part.present?
    assert mail.text_part.present?
    assert_equal "text/html", mail.html_part.content_type.split(";").first
    assert_equal "text/plain", mail.text_part.content_type.split(";").first
  end

  test "subscription_ended email compiles MJML to responsive HTML" do
    user = create(:user)
    mail = UserMailer.subscription_ended(user)

    html_body = mail.html_part.body.to_s

    # Check MJML compiled to HTML (should have tables, not mj- tags)
    assert_match(/<table/, html_body)
    refute_match(/<mj-/, html_body)
  end

  # Edge cases
  test "welcome_to_premium email correctly escapes user names with apostrophes in HTML" do
    user = create(:user, name: "Graig D'Amore")
    mail = UserMailer.welcome_to_premium(user)

    # HTML part should escape the apostrophe as &#39;
    assert_match "Hi Graig D&#39;Amore!", mail.html_part.body.to_s
    # Text part should keep the literal apostrophe
    assert_match "Hi Graig D'Amore!", mail.text_part.body.to_s
  end

  test "emails do not include unsubscribe headers" do
    user = create(:user)

    [
      UserMailer.welcome_to_premium(user),
      UserMailer.welcome_to_max(user),
      UserMailer.subscription_ended(user)
    ].each do |mail|
      # Transactional emails should not have unsubscribe headers
      assert_nil mail.header['List-Unsubscribe']
      assert_nil mail.header['List-Unsubscribe-Post']
    end
  end
end
