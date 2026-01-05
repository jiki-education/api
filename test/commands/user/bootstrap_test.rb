require "test_helper"

class User::BootstrapTest < ActiveSupport::TestCase
  test "enqueues welcome email" do
    user = create(:user)

    assert_enqueued_with(
      job: MandateJob,
      args: ["User::SendWelcomeEmail", user],
      queue: "mailers"
    ) do
      User::Bootstrap.(user)
    end
  end

  test "works with newly created user" do
    user = build(:user)
    user.save!

    assert_enqueued_jobs 1, only: MandateJob do
      User::Bootstrap.(user)
    end
  end

  # First level creation tests
  test "creates user_level for first level" do
    level1 = create(:level, position: 1)
    create(:level, position: 2)
    create(:level, position: 3)
    user = create(:user)

    User::Bootstrap.(user)

    user_level = UserLevel.find_by(user:, level: level1)
    refute_nil user_level
    assert_equal level1.id, user.reload.current_user_level&.level_id
  end

  test "calls UserLevel::Start with first level" do
    user = create(:user)
    level1 = create(:level, position: 1)

    UserLevel::Start.expects(:call).with(user, level1)

    User::Bootstrap.(user)
  end

  test "handles missing levels gracefully" do
    user = create(:user)
    # No levels exist

    assert_nothing_raised do
      User::Bootstrap.(user)
    end

    assert_nil UserLevel.find_by(user:)
  end

  test "uses lowest position level as first" do
    level5 = create(:level, position: 5)
    level10 = create(:level, position: 10)
    level1 = create(:level, position: 1)
    user = create(:user)

    User::Bootstrap.(user)

    user_level = UserLevel.find_by(user:, level: level1)
    refute_nil user_level
    assert_nil UserLevel.find_by(user:, level: level5)
    assert_nil UserLevel.find_by(user:, level: level10)
  end

  # Badge tests
  test "enqueues member badge award job" do
    user = create(:user)

    assert_enqueued_with(job: AwardBadgeJob, args: [user, 'member']) do
      User::Bootstrap.(user)
    end
  end

  test "awards member badge to new user" do
    user = create(:user)

    perform_enqueued_jobs do
      User::Bootstrap.(user)
    end

    assert user.acquired_badges.joins(:badge).where(badges: { type: 'Badges::MemberBadge' }).exists?
  end
end
