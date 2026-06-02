require "test_helper"

class Analytics::TrackLastActiveOnTest < ActiveSupport::TestCase
  test "records today and defers site_visited event on first ever visit" do
    user = create(:user)

    Analytics::TrackEvent.expects(:defer).with(user, "site_visited")

    Analytics::TrackLastActiveOn.(user)

    assert_equal Date.current, user.data.reload.last_active_on
  end

  test "records today and defers site_visited event when last active before today" do
    user = create(:user)
    user.data.update!(last_active_on: Date.current - 1.day)

    Analytics::TrackEvent.expects(:defer).with(user, "site_visited")

    Analytics::TrackLastActiveOn.(user)

    assert_equal Date.current, user.data.reload.last_active_on
  end

  test "no-ops when already active today" do
    user = create(:user)
    user.data.update!(last_active_on: Date.current)

    Analytics::TrackEvent.expects(:defer).never

    Analytics::TrackLastActiveOn.(user)
  end

  test "does not send event when a concurrent request claims today first" do
    user = create(:user)

    # Load user data into memory, then simulate another request claiming
    # today behind this command's back (so the in-memory check passes but
    # the atomic SQL claim does not).
    user.data
    User::Data.where(user_id: user.id).update_all(last_active_on: Date.current)

    Analytics::TrackEvent.expects(:defer).never

    Analytics::TrackLastActiveOn.(user)
  end
end
