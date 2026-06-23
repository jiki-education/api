require "test_helper"

class Mailshot::SendTest < ActiveSupport::TestCase
  test "records the audience and defers the fan-out" do
    mailshot = create(:mailshot)

    Mailshot::SendToSegment.expects(:defer).with(mailshot, "all_users")

    Mailshot::Send.(mailshot, "all_users")

    assert_equal ["all_users"], mailshot.reload.sent_to_audiences
  end

  test "appends to existing audiences" do
    mailshot = create(:mailshot, sent_to_audiences: ["premium_users"])

    Mailshot::SendToSegment.expects(:defer).with(mailshot, "all_users")

    Mailshot::Send.(mailshot, "all_users")

    assert_equal %w[premium_users all_users], mailshot.reload.sent_to_audiences
  end

  test "is a no-op for an already-sent segment" do
    mailshot = create(:mailshot, :sent) # all_users

    Mailshot::SendToSegment.expects(:defer).never

    Mailshot::Send.(mailshot, "all_users")

    assert_equal ["all_users"], mailshot.reload.sent_to_audiences
  end

  test "raises for an unknown segment" do
    mailshot = create(:mailshot)

    assert_raises(Mailshot::UnknownSegmentError) do
      Mailshot::Send.(mailshot, "nonsense")
    end
  end

  test "raises when the body is blank" do
    mailshot = create(:mailshot, body_markdown: "")

    Mailshot::SendToSegment.expects(:defer).never

    assert_raises(Mailshot::BlankBodyError) do
      Mailshot::Send.(mailshot, "all_users")
    end
  end
end
