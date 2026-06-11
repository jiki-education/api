require "test_helper"

class User::Exercism::ReconcileEntitlementsTest < ActiveSupport::TestCase
  test "insider+bootcamp grants both" do
    user = create(:user)

    User::PremiumEntitlement::Grant.expects(:call).with(user, PremiumEntitlement::EXERCISM_INSIDER)
    User::PremiumEntitlement::Grant.expects(:call).with(user, PremiumEntitlement::EXERCISM_BOOTCAMP)

    User::Exercism::ReconcileEntitlements.(user, is_insider: true, is_bootcamp_member: true)
  end

  test "insider only grants insider, revokes bootcamp not attempted" do
    user = create(:user)

    User::PremiumEntitlement::Grant.expects(:call).with(user, PremiumEntitlement::EXERCISM_INSIDER)
    User::PremiumEntitlement::Grant.expects(:call).with(user, PremiumEntitlement::EXERCISM_BOOTCAMP).never
    User::PremiumEntitlement::Revoke.expects(:call).with(user, PremiumEntitlement::EXERCISM_BOOTCAMP).never

    User::Exercism::ReconcileEntitlements.(user, is_insider: true, is_bootcamp_member: false)
  end

  test "bootcamp only grants bootcamp, revokes insider" do
    user = create(:user)

    User::PremiumEntitlement::Revoke.expects(:call).with(user, PremiumEntitlement::EXERCISM_INSIDER)
    User::PremiumEntitlement::Grant.expects(:call).with(user, PremiumEntitlement::EXERCISM_BOOTCAMP)

    User::Exercism::ReconcileEntitlements.(user, is_insider: false, is_bootcamp_member: true)
  end

  test "neither revokes insider and does not touch bootcamp" do
    user = create(:user)

    User::PremiumEntitlement::Revoke.expects(:call).with(user, PremiumEntitlement::EXERCISM_INSIDER)
    User::PremiumEntitlement::Revoke.expects(:call).with(user, PremiumEntitlement::EXERCISM_BOOTCAMP).never

    User::Exercism::ReconcileEntitlements.(user, is_insider: false, is_bootcamp_member: false)
  end

  test "bootcamp is one-way: false does NOT revoke an existing bootcamp entitlement" do
    user = create(:user)
    create(:premium_entitlement, :bootcamp, user:)

    User::Exercism::ReconcileEntitlements.(user, is_insider: false, is_bootcamp_member: false)

    assert user.premium_entitlements.active.where(source: PremiumEntitlement::EXERCISM_BOOTCAMP).exists?
  end
end
