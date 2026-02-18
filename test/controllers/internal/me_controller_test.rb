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
    assert json["user"].key?("premium_prices")
  end

  test "GET show returns correct membership_type for premium user" do
    @user.data.update!(membership_type: "premium")

    get internal_me_path, as: :json

    assert_response :success

    json = response.parsed_body
    assert_equal "premium", json["user"]["membership_type"]
  end

  test "sets country_code from CF-IPCountry header when nil" do
    assert_nil @user.data.country_code

    get internal_me_path, headers: { "CF-IPCountry" => "IN" }, as: :json

    assert_response :success
    assert_equal "IN", @user.data.reload.country_code
  end

  test "does not overwrite existing country_code" do
    @user.data.update_column(:country_code, "GB")

    get internal_me_path, headers: { "CF-IPCountry" => "IN" }, as: :json

    assert_response :success
    assert_equal "GB", @user.data.reload.country_code
  end

  test "ignores XX country code from CF-IPCountry" do
    get internal_me_path, headers: { "CF-IPCountry" => "XX" }, as: :json

    assert_response :success
    assert_nil @user.data.reload.country_code
  end
end
