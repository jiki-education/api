require "test_helper"

class Pricing::DeterminePricesTest < ActiveSupport::TestCase
  test "returns the local prices for a mapped country" do
    assert_equal(
      {
        currency: :gbp,
        monthly: PREMIUM_PRICES[:gbp][:monthly],
        annual: PREMIUM_PRICES[:gbp][:annual],
        lifetime: PREMIUM_PRICES[:gbp][:lifetime],
        lifetime_price_id: Jiki.config.stripe_premium_lifetime_price_id
      },
      Pricing::DeterminePrices.("GB")
    )
  end

  test "prices every CFA franc country in its franc" do
    %w[BF BJ CI GW ML NE SN TG].each do |country|
      assert_equal :xof, Pricing::DeterminePrices.(country)[:currency], "#{country} should be priced in XOF"
    end

    %w[CF CG CM GA GQ TD].each do |country|
      assert_equal :xaf, Pricing::DeterminePrices.(country)[:currency], "#{country} should be priced in XAF"
    end
  end

  test "falls back to USD without a country" do
    result = Pricing::DeterminePrices.(nil)

    assert_equal :usd, result[:currency]
    assert_equal PREMIUM_PRICES[:usd][:lifetime], result[:lifetime]
  end

  test "falls back to USD for an unmapped country" do
    assert_equal :usd, Pricing::DeterminePrices.("XX")[:currency]
  end

  test "returns the standard USD prices for a USD country outside the low tier" do
    result = Pricing::DeterminePrices.("PA")

    assert_equal :usd, result[:currency]
    assert_equal PREMIUM_PRICES[:usd][:lifetime], result[:lifetime]
    assert_equal Jiki.config.stripe_premium_lifetime_price_id, result[:lifetime_price_id]
  end

  test "returns the low USD lifetime price for a low-tier country" do
    assert_equal(
      {
        currency: :usd,
        monthly: PREMIUM_PRICES[:usd][:monthly],
        annual: PREMIUM_PRICES[:usd][:annual],
        lifetime: LOW_USD_LIFETIME_PRICE,
        lifetime_price_id: Jiki.config.stripe_premium_lifetime_low_usd_price_id
      },
      Pricing::DeterminePrices.("EC")
    )
  end

  test "every low-tier country is priced in USD" do
    LOW_USD_COUNTRIES.each do |country|
      assert_equal "usd", COUNTRY_CURRENCIES[country], "#{country} must map to usd to get the low USD price"
    end
  end
end
