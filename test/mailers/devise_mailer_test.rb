require "test_helper"

class DeviseMailerTest < ActionMailer::TestCase
  test "reset_password_instructions renders with English locale" do
    user = create(:user, name: "John Doe", locale: "en")
    token = "abc123token"

    mail = DeviseMailer.reset_password_instructions(user, token)

    assert_equal "Reset Your Password", mail.subject
    assert_equal ["noreply@jiki.app"], mail.from
    assert_equal [user.email], mail.to

    # Check HTML body contains English text
    assert_match "Hi John Doe,", mail.html_part.body.to_s
    assert_match "Someone requested a link to reset your password", mail.html_part.body.to_s
    assert_match "Reset My Password", mail.html_part.body.to_s
    assert_match "you can safely ignore this email", mail.html_part.body.to_s
    assert_match "expire in 6 hours", mail.html_part.body.to_s

    # Check text body
    assert_match "Hi John Doe,", mail.text_part.body.to_s
    assert_match "Someone requested a link to reset your password", mail.text_part.body.to_s
  end

  test "reset_password_instructions renders with Hungarian locale" do
    user = create(:user, :hungarian, name: "János Kovács", locale: "hu")
    token = "abc123token"

    mail = DeviseMailer.reset_password_instructions(user, token)

    assert_equal "Jelszó visszaállítása", mail.subject
    assert_equal ["noreply@jiki.app"], mail.from
    assert_equal [user.email], mail.to

    # Check HTML body contains Hungarian text
    assert_match "Szia János Kovács,", mail.html_part.body.to_s
    assert_match "Valaki jelszó-visszaállítási linket kért", mail.html_part.body.to_s
    assert_match "Jelszó visszaállítása", mail.html_part.body.to_s
    assert_match "figyelmen kívül hagyhatod", mail.html_part.body.to_s
    assert_match "6 óra múlva lejár", mail.html_part.body.to_s

    # Check text body
    assert_match "Szia János Kovács,", mail.text_part.body.to_s
  end

  test "reset_password_instructions includes frontend URL with token" do
    user = create(:user, name: "Test User", locale: "en")
    token = "secure_reset_token_123"

    # Mock config to have predictable URL
    Jiki.config.stubs(:frontend_base_url).returns("http://test.example.com")

    mail = DeviseMailer.reset_password_instructions(user, token)

    expected_url = "http://test.example.com/auth/reset-password?token=#{token}"

    # Check URL in HTML body
    assert_match expected_url, mail.html_part.body.to_s

    # Check URL in text body
    assert_match expected_url, mail.text_part.body.to_s
  end

  test "reset_password_instructions uses email when name is nil" do
    user = create(:user, name: nil, email: "test@example.com", locale: "en")
    token = "abc123"

    mail = DeviseMailer.reset_password_instructions(user, token)

    # Should use email in greeting when name is not available
    assert_match "Hi test@example.com,", mail.html_part.body.to_s
  end

  test "reset_password_instructions compiles MJML to responsive HTML" do
    user = create(:user)
    token = "abc123"

    mail = DeviseMailer.reset_password_instructions(user, token)

    html_body = mail.html_part.body.to_s

    # Check MJML compiled to HTML (should have tables, not mj- tags)
    assert_match(/<table/, html_body)
    refute_match(/<mj-/, html_body)

    # Check responsive email structure
    assert_match(/<!doctype html>/i, html_body)
    assert_match(/viewport/, html_body)
  end

  test "reset_password_instructions includes both HTML and text parts" do
    user = create(:user)
    token = "abc123"

    mail = DeviseMailer.reset_password_instructions(user, token)

    assert mail.html_part.present?
    assert mail.text_part.present?
    assert_equal "text/html", mail.html_part.content_type.split(";").first
    assert_equal "text/plain", mail.text_part.content_type.split(";").first
  end

  test "reset_password_instructions defaults to English for missing locale" do
    user = build(:user, locale: nil)
    # Manually set locale to nil to test default behavior
    user.define_singleton_method(:locale) { nil }
    token = "abc123"

    mail = DeviseMailer.reset_password_instructions(user, token)

    # DeviseMailer defaults to I18n.default_locale (en) when user.locale is nil
    assert_equal "Reset Your Password", mail.subject
    # Check for English text in the email
    assert_match "Someone requested a link to reset your password", mail.html_part.body.to_s
    assert_match "Reset My Password", mail.html_part.body.to_s
  end

  test "reset_password_instructions uses correct mailer sender" do
    user = create(:user)
    token = "abc123"

    mail = DeviseMailer.reset_password_instructions(user, token)

    # Check configured sender (from devise.rb)
    assert_equal ["noreply@jiki.app"], mail.from
  end

  # Confirmation instructions tests
  test "confirmation_instructions renders with English locale" do
    user = create(:user, :unconfirmed, name: "John Doe", locale: "en")
    token = "confirmation_token_123"

    mail = DeviseMailer.confirmation_instructions(user, token)

    assert_equal "Confirm Your Email Address", mail.subject
    assert_equal ["noreply@jiki.app"], mail.from
    assert_equal [user.email], mail.to

    # Check HTML body contains English text
    assert_match "Hi John Doe,", mail.html_part.body.to_s
    assert_match "Please confirm your email address", mail.html_part.body.to_s
    assert_match "Confirm My Email", mail.html_part.body.to_s

    # Check text body
    assert_match "Hi John Doe,", mail.text_part.body.to_s
    assert_match "Please confirm your email address", mail.text_part.body.to_s
  end

  test "confirmation_instructions renders with Hungarian locale" do
    user = create(:user, :unconfirmed, :hungarian, name: "János Kovács", locale: "hu")
    token = "confirmation_token_123"

    mail = DeviseMailer.confirmation_instructions(user, token)

    assert_equal "Erősítsd meg az e-mail címedet", mail.subject
    assert_equal ["noreply@jiki.app"], mail.from
    assert_equal [user.email], mail.to

    # Check HTML body contains Hungarian text
    assert_match "Szia János Kovács,", mail.html_part.body.to_s
    assert_match "erősítsd meg az e-mail címedet", mail.html_part.body.to_s
    assert_match "E-mail cím megerősítése", mail.html_part.body.to_s

    # Check text body
    assert_match "Szia János Kovács,", mail.text_part.body.to_s
  end

  test "confirmation_instructions includes frontend URL with token" do
    user = create(:user, :unconfirmed, name: "Test User", locale: "en")
    token = "secure_confirmation_token_456"

    Jiki.config.stubs(:frontend_base_url).returns("http://test.example.com")

    mail = DeviseMailer.confirmation_instructions(user, token)

    expected_url = "http://test.example.com/auth/confirm-email?token=#{token}"

    # Check URL in HTML body
    assert_match expected_url, mail.html_part.body.to_s

    # Check URL in text body
    assert_match expected_url, mail.text_part.body.to_s
  end

  test "confirmation_instructions sends to unconfirmed_email when present" do
    user = create(:user, email: "old@example.com", locale: "en")
    user.update_column(:unconfirmed_email, "new@example.com")
    token = "reconfirm_token"

    mail = DeviseMailer.confirmation_instructions(user, token)

    assert_equal ["new@example.com"], mail.to
  end

  test "confirmation_instructions includes both HTML and text parts" do
    user = create(:user, :unconfirmed)
    token = "abc123"

    mail = DeviseMailer.confirmation_instructions(user, token)

    assert mail.html_part.present?
    assert mail.text_part.present?
    assert_equal "text/html", mail.html_part.content_type.split(";").first
    assert_equal "text/plain", mail.text_part.content_type.split(";").first
  end

  test "reset_password_instructions includes reset button in HTML" do
    user = create(:user, locale: "en")
    token = "abc123"

    mail = DeviseMailer.reset_password_instructions(user, token)

    html_body = mail.html_part.body.to_s

    # Should have button with reset URL
    assert_match(/Reset My Password/, html_body)
    assert_match(%r{auth/reset-password\?token=#{token}}, html_body)
  end
end
