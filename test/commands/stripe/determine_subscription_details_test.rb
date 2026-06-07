require "test_helper"

class Stripe::DetermineSubscriptionDetailsTest < ActiveSupport::TestCase
  test "price_id_for returns monthly price ID" do
    assert_equal Jiki.config.stripe_premium_monthly_price_id,
      Stripe::DetermineSubscriptionDetails.price_id_for('monthly')
  end

  test "price_id_for returns annual price ID" do
    assert_equal Jiki.config.stripe_premium_annual_price_id,
      Stripe::DetermineSubscriptionDetails.price_id_for('annual')
  end

  test "price_id_for raises for unknown interval" do
    error = assert_raises(ArgumentError) do
      Stripe::DetermineSubscriptionDetails.price_id_for('weekly')
    end
    assert_match(/Unknown interval/, error.message)
  end

  test "interval_for_price_id returns monthly for monthly price ID" do
    assert_equal 'monthly',
      Stripe::DetermineSubscriptionDetails.interval_for_price_id(Jiki.config.stripe_premium_monthly_price_id)
  end

  test "interval_for_price_id returns annual for annual price ID" do
    assert_equal 'annual',
      Stripe::DetermineSubscriptionDetails.interval_for_price_id(Jiki.config.stripe_premium_annual_price_id)
  end

  test "interval_for_price_id raises for unknown price ID" do
    error = assert_raises(ArgumentError) do
      Stripe::DetermineSubscriptionDetails.interval_for_price_id('price_unknown')
    end
    assert_match(/Unknown Stripe price ID/, error.message)
  end
end
