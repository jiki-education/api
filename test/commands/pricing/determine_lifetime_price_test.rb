require "test_helper"

class Pricing::DetermineLifetimePriceTest < ActiveSupport::TestCase
  test "returns the standard price for the currency" do
    assert_equal(
      { amount_in_cents: PREMIUM_PRICES[:gbp][:lifetime], stripe_price_id: Jiki.config.stripe_premium_lifetime_price_id },
      Pricing::DetermineLifetimePrice.("GB", :gbp)
    )
  end

  test "returns the standard USD price for a USD country outside the low tier" do
    assert_equal(
      { amount_in_cents: 2999, stripe_price_id: Jiki.config.stripe_premium_lifetime_price_id },
      Pricing::DetermineLifetimePrice.("PA", :usd)
    )
  end

  test "returns the standard USD price without a country" do
    assert_equal 2999, Pricing::DetermineLifetimePrice.(nil, :usd)[:amount_in_cents]
  end

  test "returns the low USD price for a low-tier country" do
    assert_equal(
      { amount_in_cents: 1299, stripe_price_id: Jiki.config.stripe_premium_lifetime_low_usd_price_id },
      Pricing::DetermineLifetimePrice.("EC", :usd)
    )
  end

  test "accepts the currency as a string" do
    assert_equal 1299, Pricing::DetermineLifetimePrice.("EC", "usd")[:amount_in_cents]
  end

  test "every low-tier country is priced in USD" do
    LOW_USD_COUNTRIES.each do |country|
      assert_equal "usd", COUNTRY_CURRENCIES[country], "#{country} must map to usd to get the low USD price"
    end
  end
end
