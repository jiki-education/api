require "test_helper"

class User::Mailshot::SendTest < ActiveSupport::TestCase
  test "creates a record and sends the email" do
    user = create(:user)
    mailshot = create(:mailshot)

    assert_difference "User::Mailshot.count", 1 do
      assert_enqueued_jobs 1, only: MailDeliveryJob do
        User::Mailshot::Send.(user, mailshot)
      end
    end

    record = User::Mailshot.last
    assert_equal user, record.user
    assert_equal mailshot, record.mailshot
    assert record.email_sent?
  end

  test "is idempotent — never creates a duplicate or resends" do
    user = create(:user)
    mailshot = create(:mailshot)
    User::Mailshot::Send.(user, mailshot)

    User::SendEmail.expects(:call).never

    assert_no_difference "User::Mailshot.count" do
      assert_no_enqueued_jobs only: MailDeliveryJob do
        User::Mailshot::Send.(user, mailshot)
      end
    end
  end

  test "marks skipped and sends nothing when the user has opted out" do
    user = create(:user)
    user.data.update!(receive_newsletters: false)
    mailshot = create(:mailshot)

    assert_no_enqueued_jobs only: MailDeliveryJob do
      User::Mailshot::Send.(user, mailshot)
    end

    assert User::Mailshot.last.email_skipped?
  end
end
