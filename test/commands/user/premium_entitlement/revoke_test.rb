require "test_helper"

class User::PremiumEntitlement::RevokeTest < ActiveSupport::TestCase
  test "revokes active entitlement" do
    user = create(:user)
    entitlement = create(:premium_entitlement, :insider, user:)

    User::PremiumEntitlement::Revoke.(user, PremiumEntitlement::EXERCISM_INSIDER)

    assert entitlement.reload.revoked_at
  end

  test "fires DowngradeToStandard on 1->0 transition" do
    user = create(:user)
    create(:premium_entitlement, :insider, user:)

    User::DowngradeToStandard.expects(:call).with(user)

    User::PremiumEntitlement::Revoke.(user, PremiumEntitlement::EXERCISM_INSIDER)
  end

  test "does not fire DowngradeToStandard when Stripe still active" do
    user = create(:user)
    user.data.update!(subscription_status: "active")
    create(:premium_entitlement, :insider, user:)

    User::DowngradeToStandard.expects(:call).never

    User::PremiumEntitlement::Revoke.(user, PremiumEntitlement::EXERCISM_INSIDER)
  end

  test "does not fire DowngradeToStandard when another entitlement keeps user premium" do
    user = create(:user)
    create(:premium_entitlement, :insider, user:)
    create(:premium_entitlement, :bootcamp, user:)

    User::DowngradeToStandard.expects(:call).never

    User::PremiumEntitlement::Revoke.(user, PremiumEntitlement::EXERCISM_INSIDER)
  end

  test "no-ops when no active entitlement exists" do
    user = create(:user)

    User::DowngradeToStandard.expects(:call).never

    assert_nothing_raised do
      User::PremiumEntitlement::Revoke.(user, PremiumEntitlement::EXERCISM_INSIDER)
    end
  end

  test "no-ops when only revoked entitlements exist" do
    user = create(:user)
    create(:premium_entitlement, :insider, :revoked, user:)

    User::DowngradeToStandard.expects(:call).never

    User::PremiumEntitlement::Revoke.(user, PremiumEntitlement::EXERCISM_INSIDER)
  end
end
