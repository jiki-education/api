require "test_helper"

class Mailshot::SendToSegmentTest < ActiveSupport::TestCase
  test "sends to each user in the segment and reschedules the next batch" do
    users = create_list(:user, 2).sort_by(&:id)
    mailshot = create(:mailshot)

    users.each { |user| User::Mailshot::Send.expects(:call).with(user, mailshot) }
    Mailshot::SendToSegment.expects(:defer).with(
      mailshot, "all_users", limit: 100, offset: 100, wait: 5.seconds
    )

    Mailshot::SendToSegment.(mailshot, "all_users")
  end

  test "only targets users in the segment" do
    premium = make_premium(create(:user))
    create(:user) # free — must be excluded
    mailshot = create(:mailshot)

    User::Mailshot::Send.expects(:call).with(premium, mailshot).once
    Mailshot::SendToSegment.stubs(:defer)

    Mailshot::SendToSegment.(mailshot, "premium_users")
  end

  test "stops without rescheduling when the batch is empty" do
    mailshot = create(:mailshot)

    User::Mailshot::Send.expects(:call).never
    Mailshot::SendToSegment.expects(:defer).never

    Mailshot::SendToSegment.(mailshot, "all_users", limit: 100, offset: 100)
  end
end
