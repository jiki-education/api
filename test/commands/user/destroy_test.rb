require "test_helper"

class User::DestroyTest < ActiveSupport::TestCase
  test "successfully destroys user" do
    user = create(:user)
    user_id = user.id

    assert_difference -> { User.count }, -1 do
      User::Destroy.(user)
    end

    assert_nil User.find_by(id: user_id)
  end

  test "destroys associated records due to dependent: :destroy" do
    user_lesson = create(:user_lesson)
    user = user_lesson.user

    assert_difference -> { UserLesson.count }, -1 do
      assert_difference -> { UserLevel.count }, -1 do
        assert_difference -> { UserCourse.count }, -1 do
          User::Destroy.(user)
        end
      end
    end
  end

  test "handles circular foreign key constraint with current_user_level in user_course" do
    user_level = create(:user_level)
    user_course = UserCourse.find_by(user: user_level.user, course: user_level.course)
    user_course.update_column(:current_user_level_id, user_level.id)

    assert_nothing_raised do
      User::Destroy.(user_level.user)
    end

    assert_nil User.find_by(id: user_level.user_id)
    assert_nil UserLevel.find_by(id: user_level.id)
    assert_nil UserCourse.find_by(id: user_course.id)
  end

  test "cancels stripe subscription before destroying user" do
    user = create(:user)
    user.data.update!(stripe_subscription_id: "sub_123", subscription_status: "active")

    ::Stripe::Subscription.expects(:cancel).with("sub_123").returns(mock)

    assert_difference -> { User.count }, -1 do
      User::Destroy.(user)
    end
  end

  test "destroys user without stripe subscription" do
    user = create(:user)
    user.data.update!(stripe_subscription_id: nil)

    ::Stripe::Subscription.expects(:cancel).never

    assert_difference -> { User.count }, -1 do
      User::Destroy.(user)
    end
  end

  test "does not destroy user when stripe cancellation fails" do
    user = create(:user)
    user.data.update!(stripe_subscription_id: "sub_123", subscription_status: "active")

    error = ::Stripe::APIError.new("Stripe is down")
    ::Stripe::Subscription.expects(:cancel).with("sub_123").raises(error)

    assert_no_difference -> { User.count } do
      assert_raises(StripeSubscriptionCancellationError) do
        User::Destroy.(user)
      end
    end
  end
end
