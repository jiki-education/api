require "test_helper"

class Mailshot::SendTestEmailTest < ActiveSupport::TestCase
  test "sends to the given user without creating a record" do
    admin = create(:user, :admin)
    mailshot = create(:mailshot)

    assert_no_difference "User::Mailshot.count" do
      assert_enqueued_jobs 1, only: ActionMailer::MailDeliveryJob do
        Mailshot::SendTestEmail.(mailshot, admin)
      end
    end
  end

  test "sends even when the recipient has opted out" do
    admin = create(:user, :admin)
    admin.data.update!(receive_newsletters: false)
    mailshot = create(:mailshot)

    assert_enqueued_jobs 1, only: ActionMailer::MailDeliveryJob do
      Mailshot::SendTestEmail.(mailshot, admin)
    end
  end
end
