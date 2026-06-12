require "test_helper"

class User::PremiumEntitlement::GrantTest < ActiveSupport::TestCase
  test "creates an active entitlement" do
    user = create(:user)

    User::PremiumEntitlement::Grant.(user, PremiumEntitlement::EXERCISM_INSIDER)

    entitlement = user.premium_entitlements.active.find_by(source: PremiumEntitlement::EXERCISM_INSIDER)
    assert entitlement
  end

  test "fires UpgradeToPremium on 0->1 transition" do
    user = create(:user)

    User::UpgradeToPremium.expects(:call).with(user, source: PremiumEntitlement::EXERCISM_INSIDER)

    User::PremiumEntitlement::Grant.(user, PremiumEntitlement::EXERCISM_INSIDER)
  end

  test "does not fire UpgradeToPremium when user already premium via Stripe" do
    user = create(:user)
    user.data.update!(subscription_status: "active")

    User::UpgradeToPremium.expects(:call).never

    User::PremiumEntitlement::Grant.(user, PremiumEntitlement::EXERCISM_INSIDER)
  end

  test "does not fire UpgradeToPremium when user already has an entitlement of same source" do
    user = create(:user)
    create(:premium_entitlement, :insider, user:)

    User::UpgradeToPremium.expects(:call).never

    User::PremiumEntitlement::Grant.(user, PremiumEntitlement::EXERCISM_INSIDER)
  end

  test "does not fire UpgradeToPremium when user already has an entitlement of different source" do
    user = create(:user)
    create(:premium_entitlement, :bootcamp, user:)

    User::UpgradeToPremium.expects(:call).never

    User::PremiumEntitlement::Grant.(user, PremiumEntitlement::EXERCISM_INSIDER)
  end

  test "updates expires_at on existing active entitlement" do
    user = create(:user)
    entitlement = create(:premium_entitlement, :insider, user:, expires_at: 1.day.from_now)
    new_expiry = 30.days.from_now

    User::PremiumEntitlement::Grant.(user, PremiumEntitlement::EXERCISM_INSIDER, expires_at: new_expiry)

    assert_in_delta new_expiry.to_i, entitlement.reload.expires_at.to_i, 1
  end

  test "creates a fresh entitlement after a prior one was revoked" do
    user = create(:user)
    create(:premium_entitlement, :insider, :revoked, user:)

    User::PremiumEntitlement::Grant.(user, PremiumEntitlement::EXERCISM_INSIDER)

    assert_equal 1, user.premium_entitlements.active.where(source: PremiumEntitlement::EXERCISM_INSIDER).count
  end
end
