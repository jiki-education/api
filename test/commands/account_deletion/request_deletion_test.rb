require "test_helper"

class AccountDeletion::RequestDeletionTest < ActiveSupport::TestCase
  test "sends account deletion confirmation email" do
    user = create(:user)

    assert_enqueued_with(job: ActionMailer::MailDeliveryJob) do
      AccountDeletion::RequestDeletion.(user)
    end
  end

  test "generates confirmation URL with token" do
    user = create(:user)

    AccountMailer.expects(:account_deletion_confirmation).with(
      user,
      confirmation_url: regexp_matches(%r{#{Jiki.config.frontend_base_url}/delete-account/confirm\?token=.+})
    ).returns(mock(deliver_later: true))

    AccountDeletion::RequestDeletion.(user)
  end
end
