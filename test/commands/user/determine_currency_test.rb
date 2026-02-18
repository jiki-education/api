require "test_helper"

class User::DetermineCurrencyTest < ActiveSupport::TestCase
  test "returns usd when country_code is nil" do
    user = create(:user)
    assert_nil user.data.country_code

    assert_equal "usd", User::DetermineCurrency.(user)
  end

  test "returns usd for US country" do
    user = create(:user)
    user.data.update_column(:country_code, "US")

    assert_equal "usd", User::DetermineCurrency.(user)
  end

  test "returns inr for India" do
    user = create(:user)
    user.data.update_column(:country_code, "IN")

    assert_equal "inr", User::DetermineCurrency.(user)
  end

  test "returns gbp for GB" do
    user = create(:user)
    user.data.update_column(:country_code, "GB")

    assert_equal "gbp", User::DetermineCurrency.(user)
  end

  test "returns eur for EUR countries" do
    user = create(:user)
    user.data.update_column(:country_code, "ES")

    assert_equal "eur", User::DetermineCurrency.(user)
  end

  test "returns usd for unknown country" do
    user = create(:user)
    user.data.update_column(:country_code, "XX")

    assert_equal "usd", User::DetermineCurrency.(user)
  end
end
