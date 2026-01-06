require "test_helper"

class AwardBadgeJobTest < ActiveJob::TestCase
  test "calls User::AcquiredBadge::Create with correct params" do
    user = create(:user)

    User::AcquiredBadge::Create.expects(:call).with(user, 'member')

    AwardBadgeJob.perform_now(user, 'member')
  end

  test "discards job when BadgeCriteriaNotFulfilledError raised" do
    user = create(:user)

    # This badge requires completing solve-a-maze lesson
    assert_nothing_raised do
      AwardBadgeJob.perform_now(user, 'maze_navigator')
    end

    # Badge should not be acquired
    assert_equal 0, user.acquired_badges.count
  end

  test "queues to default queue" do
    assert_equal "default", AwardBadgeJob.new.queue_name
  end
end
