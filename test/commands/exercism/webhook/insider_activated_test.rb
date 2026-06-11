require "test_helper"

class Exercism::Webhook::InsiderActivatedTest < ActiveSupport::TestCase
  test "grants insider entitlement to the user" do
    user = create(:user, exercism_id: "1530")

    User::PremiumEntitlement::Grant.expects(:call).with(user, PremiumEntitlement::EXERCISM_INSIDER)

    Exercism::Webhook::InsiderActivated.({ "exercism_id" => 1530 })
  end

  test "no-ops for unknown exercism_id" do
    User::PremiumEntitlement::Grant.expects(:call).never

    assert_nothing_raised do
      Exercism::Webhook::InsiderActivated.({ "exercism_id" => 9999 })
    end
  end
end
