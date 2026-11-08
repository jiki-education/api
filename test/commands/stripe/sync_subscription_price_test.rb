require "test_helper"

class Stripe::SyncSubscriptionPriceTest < ActiveSupport::TestCase
  test "stores the base amount when the subscription is in the price's own currency" do
    user = create(:user)
    stub_price(currency: "usd", unit_amount: 999)

    Stripe::SyncSubscriptionPrice.(user, subscription_in("usd"))

    assert_equal 999, user.data.reload.subscription_amount_in_cents
    assert_equal "usd", user.data.subscription_currency
  end

  test "stores the matching currency option for other currencies" do
    user = create(:user)
    stub_price(currency: "usd", unit_amount: 999, currency_options: { gbp: OpenStruct.new(unit_amount: 799) })

    Stripe::SyncSubscriptionPrice.(user, subscription_in("gbp"))

    assert_equal 799, user.data.reload.subscription_amount_in_cents
    assert_equal "gbp", user.data.subscription_currency
  end

  test "raises when the price has no amount in the subscription's currency" do
    user = create(:user)
    stub_price(currency: "usd", unit_amount: 999, currency_options: {})

    assert_raises(ArgumentError) { Stripe::SyncSubscriptionPrice.(user, subscription_in("gbp")) }
    assert_nil user.data.reload.subscription_amount_in_cents
  end

  private
  def subscription_in(currency)
    item = OpenStruct.new(price: OpenStruct.new(id: "price_123"))
    OpenStruct.new(currency:, items: OpenStruct.new(data: [item]))
  end

  def stub_price(currency:, unit_amount:, currency_options: nil)
    price = OpenStruct.new(id: "price_123", currency:, unit_amount:, currency_options:)
    ::Stripe::Price.stubs(:retrieve).with({ id: "price_123", expand: ["currency_options"] }).returns(price)
  end
end
