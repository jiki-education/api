require "test_helper"

class User::DataTest < ActiveSupport::TestCase
  test "standard? returns true for standard membership" do
    user = create(:user)
    user.data.update!(membership_type: "standard")
    assert user.data.standard?
    refute user.data.premium?
  end

  test "premium? returns true for premium membership" do
    user = create(:user)
    user.data.update!(membership_type: "premium")
    refute user.data.standard?
    assert user.data.premium?
  end

  test "monthly? returns true for monthly interval" do
    user = create(:user)
    user.data.update!(subscription_interval: "monthly")
    assert user.data.monthly?
    refute user.data.annual?
  end

  test "annual? returns true for annual interval" do
    user = create(:user)
    user.data.update!(subscription_interval: "annual")
    refute user.data.monthly?
    assert user.data.annual?
  end

  test "subscription_paid? returns true for standard tier" do
    user = create(:user)
    user.data.update!(membership_type: "standard")
    assert user.data.subscription_paid?
  end

  test "subscription_paid? returns true for active subscription with future subscription_valid_until" do
    user = create(:user)
    user.data.update!(
      membership_type: "premium",
      subscription_valid_until: 1.month.from_now
    )
    assert user.data.subscription_paid?
  end

  test "subscription_paid? returns false for past subscription_valid_until" do
    user = create(:user)
    user.data.update!(
      membership_type: "premium",
      subscription_valid_until: 1.day.ago
    )
    refute user.data.subscription_paid?
  end

  test "subscription_paid? returns false when no subscription_valid_until" do
    user = create(:user)
    user.data.update!(
      membership_type: "premium",
      subscription_valid_until: nil
    )
    refute user.data.subscription_paid?
  end

  test "in_grace_period? returns false when subscription is active" do
    user = create(:user)
    user.data.update!(
      membership_type: "premium",
      subscription_status: "active",
      subscription_valid_until: 1.month.from_now
    )
    refute user.data.in_grace_period?
  end

  test "in_grace_period? returns false when payment_failed but subscription_valid_until is nil" do
    user = create(:user)
    user.data.update!(
      membership_type: "premium",
      subscription_status: "payment_failed",
      subscription_valid_until: nil
    )
    refute user.data.in_grace_period?
  end

  test "in_grace_period? returns true when payment_failed and within grace period" do
    user = create(:user)
    period_end = 3.days.ago # Expired 3 days ago
    user.data.update!(
      membership_type: "premium",
      subscription_status: "payment_failed",
      subscription_valid_until: period_end
    )
    # Grace period is period_end + 7 days, so 4 days from now
    assert user.data.in_grace_period?
  end

  test "in_grace_period? returns false when payment_failed but grace period expired" do
    user = create(:user)
    period_end = 8.days.ago # Expired 8 days ago
    user.data.update!(
      membership_type: "premium",
      subscription_status: "payment_failed",
      subscription_valid_until: period_end
    )
    # Grace period was period_end + 7 days, so 1 day ago - expired
    refute user.data.in_grace_period?
  end

  test "grace_period_ends_at returns nil when subscription_valid_until is nil" do
    user = create(:user)
    user.data.update!(
      membership_type: "premium",
      subscription_valid_until: nil
    )
    assert_nil user.data.grace_period_ends_at
  end

  test "grace_period_ends_at returns subscription_valid_until + 7 days" do
    period_end = 3.days.ago
    user = create(:user)
    user.data.update!(
      membership_type: "premium",
      subscription_status: "payment_failed",
      subscription_valid_until: period_end
    )

    expected_end = period_end + 7.days
    assert_in_delta expected_end.to_i, user.data.grace_period_ends_at.to_i, 1
  end

  test "can_checkout? returns true for never_subscribed" do
    user = create(:user)
    user.data.update!(subscription_status: "never_subscribed")
    assert user.data.can_checkout?
  end

  test "can_checkout? returns true for canceled" do
    user = create(:user)
    user.data.update!(subscription_status: "canceled")
    assert user.data.can_checkout?
  end

  test "can_checkout? returns false for active" do
    user = create(:user)
    user.data.update!(subscription_status: "active")
    refute user.data.can_checkout?
  end

  test "can_change_interval? returns true for active" do
    user = create(:user)
    user.data.update!(subscription_status: "active")
    assert user.data.can_change_interval?
  end

  test "can_change_interval? returns true for payment_failed" do
    user = create(:user)
    user.data.update!(subscription_status: "payment_failed")
    assert user.data.can_change_interval?
  end

  test "can_change_interval? returns true for cancelling" do
    user = create(:user)
    user.data.update!(subscription_status: "cancelling")
    assert user.data.can_change_interval?
  end

  test "can_change_interval? returns false for never_subscribed" do
    user = create(:user)
    user.data.update!(subscription_status: "never_subscribed")
    refute user.data.can_change_interval?
  end

  test "locale returns explicit_locale when set" do
    user = create(:user)
    user.data.update!(explicit_locale: "hu")

    # An explicit choice wins outright; negotiation is never consulted.
    User::DetermineLocale.expects(:call).never
    assert_equal "hu", user.data.locale
  end

  test "locale negotiates from preferences when no explicit choice" do
    user = create(:user)
    user.data.update!(explicit_locale: nil, locales: %w[hu-HU en])

    User::DetermineLocale.expects(:call).with(%w[hu-HU en]).returns("hu")
    assert_equal "hu", user.data.locale
  end

  test "locale falls back to the default when negotiation finds nothing" do
    user = create(:user)
    user.data.update!(explicit_locale: nil, locales: %w[xx-YY])

    User::DetermineLocale.expects(:call).with(%w[xx-YY]).returns(nil)
    assert_equal I18n.default_locale.to_s, user.data.locale
  end

  test "locale ignores an explicit choice that isn't live yet" do
    user = create(:user)

    with_locales(live: %w[en], draft: %w[xx]) do
      user.data.update!(explicit_locale: "xx", locales: %w[en])

      # xx is a draft locale here, so it must not drive what we serve.
      assert_equal "en", user.data.locale
    end
  end

  test "locale honours the explicit choice once it goes live" do
    user = create(:user)

    with_locales(live: %w[en xx]) do
      user.data.update!(explicit_locale: "xx", locales: %w[en])

      assert_equal "xx", user.data.locale
    end
  end

  test "selected_locale keeps a draft choice" do
    user = create(:user)

    with_locales(live: %w[en], draft: %w[xx]) do
      user.data.update!(explicit_locale: "xx")

      assert_equal "xx", user.data.selected_locale
    end
  end

  test "selected_locale ignores a choice that's in neither the live nor draft set" do
    user = create(:user)
    user.data.update_column(:explicit_locale, "kl")

    assert_nil user.data.selected_locale
  end

  test "selected_locale is nil when no explicit choice" do
    user = create(:user)
    user.data.update!(explicit_locale: nil)

    assert_nil user.data.selected_locale
  end

  test "available_locales leads with the explicit choice, then the served locale" do
    user = create(:user)

    with_locales(live: %w[en], draft: %w[xx fr]) do
      user.data.update!(explicit_locale: "xx", locales: %w[fr en])

      # xx is chosen but not live, so en is served — both appear, choice first.
      assert_equal %w[xx en fr], user.data.available_locales
    end
  end

  test "available_locales dedupes when the explicit choice is also the served locale" do
    user = create(:user)

    with_locales(live: %w[en xx]) do
      user.data.update!(explicit_locale: "xx", locales: %w[xx en])

      assert_equal %w[xx en], user.data.available_locales
    end
  end

  test "locale= records an explicit choice, and blanks clear it" do
    user = create(:user)

    user.data.locale = "hu"
    assert_equal "hu", user.data.explicit_locale

    user.data.locale = ""
    assert_nil user.data.explicit_locale
  end

  test "timezone defaults to UTC on create" do
    user = create(:user)

    assert_equal "UTC", user.data.timezone
  end

  test "timezone is not overridden when provided" do
    user = build(:user)
    user.data.timezone = "America/New_York"
    user.save!

    assert_equal "America/New_York", user.data.timezone
  end
end
