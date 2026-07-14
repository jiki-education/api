require "test_helper"

class Mailshot::SendTestEmailTest < ActiveSupport::TestCase
  test "sends to the given admin through the normal pipeline" do
    admin = create(:user, :admin)
    mailshot = create(:mailshot)

    assert_difference "User::Mailshot.count", 1 do
      assert_enqueued_jobs 1, only: MailDeliveryJob do
        Mailshot::SendTestEmail.(mailshot, admin)
      end
    end
  end

  test "deletes any prior send record so the test can be repeated" do
    admin = create(:user, :admin)
    mailshot = create(:mailshot)
    create(:user_mailshot, user: admin, mailshot:)

    assert_no_difference "User::Mailshot.count" do
      assert_enqueued_jobs 1, only: MailDeliveryJob do
        Mailshot::SendTestEmail.(mailshot, admin)
      end
    end
  end

  test "raises when the user is not an admin" do
    user = create(:user)
    mailshot = create(:mailshot)

    assert_raises(ArgumentError) do
      Mailshot::SendTestEmail.(mailshot, user)
    end
  end
end
