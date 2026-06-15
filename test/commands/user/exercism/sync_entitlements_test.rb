require "test_helper"

class User::Exercism::SyncEntitlementsTest < ActiveSupport::TestCase
  test "defers a resync for insider gainers" do
    user = create(:user, exercism_id: "1")
    Exercism::FetchEntitledUsers.expects(:call).returns(
      "insider_ids" => ["1"], "bootcamp_member_ids" => []
    )

    User::Exercism::ResyncUser.expects(:defer).with(user)

    User::Exercism::SyncEntitlements.()
  end

  test "defers a resync for insider losers" do
    user = create(:user, exercism_id: "1")
    create(:premium_entitlement, :insider, user:)
    Exercism::FetchEntitledUsers.expects(:call).returns(
      "insider_ids" => [], "bootcamp_member_ids" => []
    )

    User::Exercism::ResyncUser.expects(:defer).with(user)

    User::Exercism::SyncEntitlements.()
  end

  test "defers a resync for bootcamp gainers" do
    user = create(:user, exercism_id: "2")
    Exercism::FetchEntitledUsers.expects(:call).returns(
      "insider_ids" => [], "bootcamp_member_ids" => ["2"]
    )

    User::Exercism::ResyncUser.expects(:defer).with(user)

    User::Exercism::SyncEntitlements.()
  end

  test "does not defer anything when local state already matches roster" do
    insider = create(:user, exercism_id: "1")
    create(:premium_entitlement, :insider, user: insider)

    bootcamp = create(:user, exercism_id: "2")
    create(:premium_entitlement, :bootcamp, user: bootcamp)

    Exercism::FetchEntitledUsers.expects(:call).returns(
      "insider_ids" => ["1"], "bootcamp_member_ids" => ["2"]
    )

    User::Exercism::ResyncUser.expects(:defer).never

    User::Exercism::SyncEntitlements.()
  end

  test "ignores roster ids that do not match any local user" do
    Exercism::FetchEntitledUsers.expects(:call).returns(
      "insider_ids" => ["999"], "bootcamp_member_ids" => ["888"]
    )

    User::Exercism::ResyncUser.expects(:defer).never

    User::Exercism::SyncEntitlements.()
  end

  test "deduplicates when a user appears in multiple delta sets" do
    user = create(:user, exercism_id: "1")
    Exercism::FetchEntitledUsers.expects(:call).returns(
      "insider_ids" => ["1"], "bootcamp_member_ids" => ["1"]
    )

    User::Exercism::ResyncUser.expects(:defer).with(user).once

    User::Exercism::SyncEntitlements.()
  end

  test "uses the default queue" do
    assert_equal :default, User::Exercism::SyncEntitlements.active_job_queue
  end
end
