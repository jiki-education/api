require "test_helper"

class Exercism::Webhook::InsiderDeactivatedTest < ActiveSupport::TestCase
  test "revokes insider entitlement from the user" do
    user = create(:user, exercism_id: "1530")

    User::PremiumEntitlement::Revoke.expects(:call).with(user, PremiumEntitlement::EXERCISM_INSIDER)

    Exercism::Webhook::InsiderDeactivated.({ "exercism_id" => 1530 })
  end

  test "no-ops for unknown exercism_id" do
    User::PremiumEntitlement::Revoke.expects(:call).never

    assert_nothing_raised do
      Exercism::Webhook::InsiderDeactivated.({ "exercism_id" => 9999 })
    end
  end
end
