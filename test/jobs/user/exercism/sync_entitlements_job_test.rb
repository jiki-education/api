require "test_helper"

class User::Exercism::SyncEntitlementsJobTest < ActiveJob::TestCase
  test "queues a resync for insider gainers" do
    user = create(:user, exercism_id: "1")
    Exercism::FetchEntitledUsers.expects(:call).returns(
      "insider_ids" => ["1"], "bootcamp_member_ids" => []
    )

    assert_enqueued_with(job: User::Exercism::ResyncUserJob, args: [user]) do
      User::Exercism::SyncEntitlementsJob.perform_now
    end
  end

  test "queues a resync for insider losers" do
    user = create(:user, exercism_id: "1")
    create(:premium_entitlement, :insider, user:)
    Exercism::FetchEntitledUsers.expects(:call).returns(
      "insider_ids" => [], "bootcamp_member_ids" => []
    )

    assert_enqueued_with(job: User::Exercism::ResyncUserJob, args: [user]) do
      User::Exercism::SyncEntitlementsJob.perform_now
    end
  end

  test "queues a resync for bootcamp gainers" do
    user = create(:user, exercism_id: "2")
    Exercism::FetchEntitledUsers.expects(:call).returns(
      "insider_ids" => [], "bootcamp_member_ids" => ["2"]
    )

    assert_enqueued_with(job: User::Exercism::ResyncUserJob, args: [user]) do
      User::Exercism::SyncEntitlementsJob.perform_now
    end
  end

  test "does not queue anything when local state already matches roster" do
    insider = create(:user, exercism_id: "1")
    create(:premium_entitlement, :insider, user: insider)

    bootcamp = create(:user, exercism_id: "2")
    create(:premium_entitlement, :bootcamp, user: bootcamp)

    Exercism::FetchEntitledUsers.expects(:call).returns(
      "insider_ids" => ["1"], "bootcamp_member_ids" => ["2"]
    )

    assert_no_enqueued_jobs only: User::Exercism::ResyncUserJob do
      User::Exercism::SyncEntitlementsJob.perform_now
    end
  end

  test "ignores roster ids that do not match any local user" do
    Exercism::FetchEntitledUsers.expects(:call).returns(
      "insider_ids" => ["999"], "bootcamp_member_ids" => ["888"]
    )

    assert_no_enqueued_jobs only: User::Exercism::ResyncUserJob do
      User::Exercism::SyncEntitlementsJob.perform_now
    end
  end

  test "deduplicates when a user appears in multiple delta sets" do
    create(:user, exercism_id: "1")
    Exercism::FetchEntitledUsers.expects(:call).returns(
      "insider_ids" => ["1"], "bootcamp_member_ids" => ["1"]
    )

    assert_enqueued_jobs 1, only: User::Exercism::ResyncUserJob do
      User::Exercism::SyncEntitlementsJob.perform_now
    end
  end
end
