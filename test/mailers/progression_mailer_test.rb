require "test_helper"

class ProgressionMailerTest < ActionMailer::TestCase
  test "level_completed email renders correctly" do
    user = create(:user)
    level = create(:level)

    mail = ProgressionMailer.level_completed(UserLevel.new(user:, level:))

    assert_equal level.milestone_email_subject, mail.subject
    assert_equal [user.email], mail.to
    assert mail.html_part.body.to_s.present?
  end

  test "level_completed renders English chrome and footer by default" do
    user = create(:user, locale: "en")
    level = create(:level)

    mail = ProgressionMailer.level_completed(UserLevel.new(user:, level:))

    html = mail.html_part.body.to_s
    text = mail.text_part.body.to_s

    # Greeting and sign-off
    assert_match "Hi there,", html
    assert_match "Cheers,", html
    assert_match "Hi there,", text
    assert_match "Cheers,", text
    assert_match "Jeremy & Team", text

    # Preview uses the (English) level title
    assert_match "completed #{level.title}!", html

    # Shared footer chrome
    assert_match "You are receiving this email because you have an account at", html
    assert_match "update your preferences", html
    assert_match "unsubscribe", html
    assert_match "from this list.", html
  end

  test "level_completed renders Hungarian chrome, footer and localized title" do
    user = create(:user, :hungarian)
    level = create(:level, :with_translations)

    mail = ProgressionMailer.level_completed(UserLevel.new(user:, level:))

    html = mail.html_part.body.to_s
    text = mail.text_part.body.to_s

    # Greeting and sign-off
    assert_match "Szia,", html
    assert_match "Üdv,", html
    assert_match "Szia,", text
    assert_match "Jeremy és a csapat", text

    # Preview uses the localized (Hungarian) level title
    assert_match "Teljesítetted ezt: Magyar cím!", html

    # Shared footer chrome (Hungarian)
    assert_match "Ezt az e-mailt azért kapod", html
    assert_match "módosítsd a beállításaidat", html
    assert_match "iratkozz le", html
  end

  test "level_completed sets @header_image based on level.position % 3" do
    user = create(:user)
    level = create(:level)

    {
      3 => "milestone-1.jpg",
      1 => "milestone-2.jpg",
      2 => "milestone-3.jpg"
    }.each do |position, expected_image|
      level.stubs(:position).returns(position)

      mail = ProgressionMailer.level_completed(UserLevel.new(user:, level:))

      assert_match "static/emails/#{expected_image}", mail.html_part.body.to_s,
        "expected #{expected_image} for position #{position}"
    end
  end
end
