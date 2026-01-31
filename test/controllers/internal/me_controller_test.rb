require "test_helper"

class Internal::MeControllerTest < ApplicationControllerTest
  setup do
    @user = create(:user)
    sign_in_user(@user)
  end

  guard_incorrect_token! :internal_me_path, method: :get

  test "GET show returns current user data" do
    get internal_me_path, as: :json

    assert_response :success

    json = response.parsed_body
    assert_equal @user.handle, json["user"]["handle"]
    assert_equal @user.email, json["user"]["email"]
    assert_equal @user.name, json["user"]["name"]
    assert_equal "standard", json["user"]["membership_type"]
    assert json["user"].key?("subscription_status")
    assert json["user"].key?("subscription")
  end

  test "GET show returns correct membership_type for premium user" do
    @user.data.update!(membership_type: "premium")

    get internal_me_path, as: :json

    assert_response :success

    json = response.parsed_body
    assert_equal "premium", json["user"]["membership_type"]
  end

  test "GET show returns correct membership_type for max user" do
    @user.data.update!(membership_type: "max")

    get internal_me_path, as: :json

    assert_response :success

    json = response.parsed_body
    assert_equal "max", json["user"]["membership_type"]
  end
end
