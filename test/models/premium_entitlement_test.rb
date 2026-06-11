require "test_helper"

class PremiumEntitlementTest < ActiveSupport::TestCase
  test "active scope includes entitlement with no expiry" do
    entitlement = create(:premium_entitlement)

    assert_includes PremiumEntitlement.active, entitlement
  end

  test "active scope includes entitlement with future expiry" do
    entitlement = create(:premium_entitlement, expires_at: 1.day.from_now)

    assert_includes PremiumEntitlement.active, entitlement
  end

  test "active scope excludes revoked entitlement" do
    entitlement = create(:premium_entitlement, :revoked)

    refute_includes PremiumEntitlement.active, entitlement
  end

  test "active scope excludes expired entitlement" do
    entitlement = create(:premium_entitlement, :expired)

    refute_includes PremiumEntitlement.active, entitlement
  end

  test "active? mirrors active scope" do
    assert create(:premium_entitlement).active?
    assert create(:premium_entitlement, expires_at: 1.day.from_now).active?
    refute create(:premium_entitlement, :revoked).active?
    refute create(:premium_entitlement, :expired).active?
  end

  test "starts_at defaults to now on create" do
    freeze_time do
      entitlement = create(:premium_entitlement, starts_at: nil)
      assert_equal Time.current, entitlement.starts_at
    end
  end

  test "unique index allows one active entitlement per user+source" do
    user = create(:user)
    create(:premium_entitlement, user:, source: PremiumEntitlement::EXERCISM_INSIDER)

    assert_raises(ActiveRecord::RecordNotUnique) do
      create(:premium_entitlement, user:, source: PremiumEntitlement::EXERCISM_INSIDER)
    end
  end

  test "unique index permits a revoked row alongside an active one" do
    user = create(:user)
    create(:premium_entitlement, :revoked, user:, source: PremiumEntitlement::EXERCISM_INSIDER)

    assert_nothing_raised do
      create(:premium_entitlement, user:, source: PremiumEntitlement::EXERCISM_INSIDER)
    end
  end

  test "unique index permits multiple revoked rows for same user+source" do
    user = create(:user)
    create(:premium_entitlement, :revoked, user:, source: PremiumEntitlement::EXERCISM_INSIDER)

    assert_nothing_raised do
      create(:premium_entitlement, :revoked, user:, source: PremiumEntitlement::EXERCISM_INSIDER)
    end
  end
end
