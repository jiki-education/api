require "test_helper"

class OnboardingMailerTest < ActionMailer::TestCase
  ACTIONS = %i[overview coding building premium community].freeze

  ACTIONS.each do |action|
    test "#{action} renders with subject, html and text bodies" do
      user = create(:user)

      mail = OnboardingMailer.public_send(action, user)

      assert_equal [user.email], mail.to
      assert mail.subject.present?, "expected #{action} email to have a subject"
      assert mail.html_part.body.to_s.present?
      assert mail.text_part.body.to_s.present?
    end

    test "#{action} skips delivery when receive_onboarding_emails is false" do
      user = create(:user)
      user.data.update!(receive_onboarding_emails: false)

      mail = OnboardingMailer.public_send(action, user)

      assert_nil mail.message_id
    end

    test "#{action} skips delivery when user may not receive emails (bounce/complaint)" do
      user = create(:user)
      user.data.update!(email_complaint_at: Time.current)

      mail = OnboardingMailer.public_send(action, user)

      assert_nil mail.message_id
    end

    test "#{action} renders in Hungarian when user locale is hu" do
      user = create(:user, :hungarian)

      mail = OnboardingMailer.public_send(action, user)

      expected_subject = I18n.t("onboarding_mailer.#{action}.subject", locale: :hu)
      assert_equal expected_subject, mail.subject
    end

    test "#{action} sets onboarding-#{action} header image" do
      user = create(:user)

      mail = OnboardingMailer.public_send(action, user)

      assert_match "static/emails/onboarding-#{action}.jpg", mail.html_part.body.to_s
    end
  end
end
