require "test_helper"

class SerializePaymentsTest < ActiveSupport::TestCase
  test "serializes empty collection" do
    assert_empty SerializePayments.([])
  end

  test "serializes single payment with all fields" do
    user = create(:user)
    payment = create(:payment,
      user:,
      payment_processor_id: "in_test123",
      amount_in_cents: 1999,
      currency: "usd",
      product: "premium",
      external_receipt_url: "https://invoice.stripe.com/test",
      created_at: Time.zone.parse("2025-01-15 10:00:00"))

    result = SerializePayments.([payment])

    assert_equal 1, result.length
    serialized = result.first

    assert_equal payment.id, serialized[:id]
    assert_equal 1999, serialized[:amount_in_cents]
    assert_equal "usd", serialized[:currency]
    assert_equal "premium", serialized[:product]
    assert_equal "https://invoice.stripe.com/test", serialized[:external_receipt_url]
    assert_equal "2025-01-15T10:00:00Z", serialized[:paid_at]
  end

  test "serializes multiple payments" do
    user = create(:user)
    payment1 = create(:payment, user:, product: "premium")
    payment2 = create(:payment, user:, product: "premium")

    result = SerializePayments.([payment1, payment2])

    assert_equal 2, result.length
    assert_equal "premium", result[0][:product]
    assert_equal "premium", result[1][:product]
  end

  test "serializes payment with nil external_receipt_url" do
    user = create(:user)
    payment = create(:payment, user:, external_receipt_url: nil)

    result = SerializePayments.([payment])

    assert_nil result.first[:external_receipt_url]
  end

  test "paid_at is formatted as ISO8601" do
    user = create(:user)
    payment = create(:payment, user:, created_at: Time.zone.parse("2025-06-15 14:30:45"))

    result = SerializePayments.([payment])

    assert_equal "2025-06-15T14:30:45Z", result.first[:paid_at]
  end
end
