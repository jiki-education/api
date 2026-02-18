require "test_helper"

class PaymentTest < ActiveSupport::TestCase
  test "valid factory" do
    assert build(:payment).valid?
  end

  test "validates presence of payment_processor_id" do
    payment = build(:payment, payment_processor_id: nil)
    refute payment.valid?
    assert_includes payment.errors[:payment_processor_id], "can't be blank"
  end

  test "database constraint raises RecordNotUnique for duplicate payment_processor_id" do
    create(:payment, payment_processor_id: "in_duplicate123")

    assert_raises(ActiveRecord::RecordNotUnique) do
      # Use insert to bypass validations and hit DB constraint directly
      Payment.insert!({
        user_id: create(:user).id,
        payment_processor_id: "in_duplicate123",
        amount_in_cents: 1999,
        currency: "usd",
        product: "premium",
        data: {},
        created_at: Time.current,
        updated_at: Time.current
      })
    end
  end

  test "validates presence of amount_in_cents" do
    payment = build(:payment, amount_in_cents: nil)
    refute payment.valid?
    assert_includes payment.errors[:amount_in_cents], "can't be blank"
  end

  test "validates amount_in_cents is greater than 0" do
    payment = build(:payment, amount_in_cents: 0)
    refute payment.valid?
    assert_includes payment.errors[:amount_in_cents], "must be greater than 0"
  end

  test "validates presence of currency" do
    payment = build(:payment, currency: nil)
    refute payment.valid?
    assert_includes payment.errors[:currency], "can't be blank"
  end

  test "validates presence of product" do
    payment = build(:payment, product: nil)
    refute payment.valid?
    assert_includes payment.errors[:product], "can't be blank"
  end

  test "validates product inclusion - premium is valid" do
    payment = build(:payment, product: "premium")
    assert payment.valid?
  end

  test "validates product inclusion - invalid value rejected" do
    payment = build(:payment, product: "invalid")
    refute payment.valid?
    assert_includes payment.errors[:product], "is not included in the list"
  end

  test "most_recent_first orders by created_at descending" do
    user = create(:user)
    old_payment = create(:payment, user:, created_at: 2.days.ago)
    new_payment = create(:payment, user:, created_at: 1.day.ago)

    assert_equal [new_payment, old_payment], user.payments.most_recent_first.to_a
  end

  test "belongs to user" do
    user = create(:user)
    payment = create(:payment, user:)

    assert_equal user, payment.user
  end

  test "user has_many payments" do
    user = create(:user)
    payment1 = create(:payment, user:)
    payment2 = create(:payment, user:)

    assert_includes user.payments, payment1
    assert_includes user.payments, payment2
  end

  test "destroying user destroys associated payments" do
    user = create(:user)
    payment = create(:payment, user:)
    payment_id = payment.id

    Prosopite.pause do
      user.destroy!
    end

    refute Payment.exists?(payment_id)
  end
end
