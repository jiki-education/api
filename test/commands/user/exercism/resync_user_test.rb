require "test_helper"

class User::Exercism::ResyncUserTest < ActiveSupport::TestCase
  test "fetches status and reconciles" do
    user = create(:user, exercism_id: "1530")

    Exercism::FetchUserStatus.expects(:call).with("1530").returns(
      "is_insider" => true, "is_bootcamp_member" => false
    )
    User::Exercism::ReconcileEntitlements.expects(:call).with(
      user, is_insider: true, is_bootcamp_member: false
    )

    User::Exercism::ResyncUser.(user)
  end

  test "no-ops for users without exercism_id" do
    user = create(:user, exercism_id: nil)

    Exercism::FetchUserStatus.expects(:call).never
    User::Exercism::ReconcileEntitlements.expects(:call).never

    User::Exercism::ResyncUser.(user)
  end

  test "uses the default queue" do
    assert_equal :default, User::Exercism::ResyncUser.active_job_queue
  end
end
