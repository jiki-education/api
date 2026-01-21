FactoryBot.define do
  factory :payment do
    user
    sequence(:payment_processor_id) { |n| "in_test#{SecureRandom.hex(8)}#{n}" }
    amount_in_cents { 1999 }
    currency { "usd" }
    product { "premium" }
    external_receipt_url { "https://invoice.stripe.com/i/#{SecureRandom.hex(16)}" }
    data do
      {
        stripe_invoice_id: payment_processor_id,
        stripe_charge_id: "ch_#{SecureRandom.hex(12)}",
        stripe_subscription_id: "sub_#{SecureRandom.hex(12)}",
        stripe_customer_id: "cus_#{SecureRandom.hex(12)}",
        billing_reason: "subscription_create",
        period_start: 1.month.ago.iso8601,
        period_end: Time.current.iso8601
      }
    end

    trait :max do
      product { "max" }
      amount_in_cents { 4999 }
    end

    trait :renewal do
      data do
        {
          stripe_invoice_id: payment_processor_id,
          stripe_charge_id: "ch_#{SecureRandom.hex(12)}",
          stripe_subscription_id: "sub_#{SecureRandom.hex(12)}",
          stripe_customer_id: "cus_#{SecureRandom.hex(12)}",
          billing_reason: "subscription_cycle",
          period_start: Time.current.iso8601,
          period_end: 1.month.from_now.iso8601
        }
      end
    end
  end
end
