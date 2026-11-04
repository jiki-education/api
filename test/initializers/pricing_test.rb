require "test_helper"

class PricingTest < ActiveSupport::TestCase
  # Stripe takes these as two-decimal, but only whole units can be charged
  WHOLE_UNIT_TWO_DECIMAL_CURRENCIES = %i[isk ugx].freeze

  # Stripe needs three-decimal amounts to end in 0
  THREE_DECIMAL_CURRENCIES = %i[bhd jod kwd omr tnd].freeze

  test "every mapped currency has a price" do
    unpriced = COUNTRY_CURRENCIES.values.uniq.map(&:to_sym) - PREMIUM_PRICES.keys

    assert_empty unpriced, "Countries map to currencies with no price, so they silently fall back to USD"
  end

  test "every currency has positive integer monthly, annual and lifetime amounts" do
    PREMIUM_PRICES.each do |currency, prices|
      assert_equal %i[monthly annual lifetime], prices.keys, "#{currency} has the wrong keys"
      prices.each do |key, amount|
        assert amount.is_a?(Integer) && amount.positive?, "#{currency} #{key} is not a positive integer"
      end
    end
  end

  # The amount checks cover lifetime, the only price new customers can buy.
  test "whole-unit two-decimal lifetime prices are divisible by 100" do
    WHOLE_UNIT_TWO_DECIMAL_CURRENCIES.each do |currency|
      next unless PREMIUM_PRICES.key?(currency)

      assert_equal 0, PREMIUM_PRICES[currency][:lifetime] % 100, "#{currency} lifetime must be divisible by 100"
    end
  end

  test "three-decimal lifetime prices end in 0" do
    THREE_DECIMAL_CURRENCIES.each do |currency|
      next unless PREMIUM_PRICES.key?(currency)

      assert_equal 0, PREMIUM_PRICES[currency][:lifetime] % 10, "#{currency} lifetime must end in 0"
    end
  end
end
