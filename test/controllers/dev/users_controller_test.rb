require "test_helper"

class Dev::UsersControllerTest < ApplicationControllerTest
  # Environment guard
  guard_dev_only! :clear_stripe_history_dev_user_path, args: [1], method: :delete

  test "DELETE clear_stripe_history clears all Stripe data and resets to standard" do
    Rails.env.stubs(:development?).returns(true)

    begin
      user = create(:user)
      user.data.update!(
        stripe_customer_id: "cus_test123",
        stripe_subscription_id: "sub_test456",
        stripe_subscription_status: "active",
        subscription_current_period_end: 1.month.from_now,
        payment_failed_at: 2.days.ago,
        membership_type: "premium"
      )

      delete clear_stripe_history_dev_user_path(user), as: :json

      assert_response :success

      # Verify response structure
      assert_json_response({
        message: "Stripe history cleared successfully",
        user: {
          id: user.id,
          handle: user.handle,
          membership_type: "standard"
        }
      })

      # Verify all Stripe fields are cleared
      user.data.reload
      assert_nil user.data.stripe_customer_id
      assert_nil user.data.stripe_subscription_id
      assert_nil user.data.stripe_subscription_status
      assert_nil user.data.subscription_current_period_end
      assert_nil user.data.payment_failed_at
      assert_equal "standard", user.data.membership_type
    ensure
      Rails.env.unstub(:development?)
    end
  end

  test "DELETE clear_stripe_history works when user has no Stripe data" do
    Rails.env.stubs(:development?).returns(true)

    begin
      user = create(:user)

      delete clear_stripe_history_dev_user_path(user), as: :json

      assert_response :success
      assert_json_response({
        message: "Stripe history cleared successfully",
        user: {
          id: user.id,
          handle: user.handle,
          membership_type: "standard"
        }
      })
    ensure
      Rails.env.unstub(:development?)
    end
  end

  test "DELETE clear_stripe_history returns 404 for non-existent user" do
    Rails.env.stubs(:development?).returns(true)

    begin
      delete clear_stripe_history_dev_user_path(99_999), as: :json

      assert_response :not_found
    ensure
      Rails.env.unstub(:development?)
    end
  end
end
