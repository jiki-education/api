require "test_helper"

class Internal::SeenFlagsControllerTest < ApplicationControllerTest
  setup do
    @user = create(:user)
    sign_in_user(@user)
  end

  guard_incorrect_token! :internal_seen_flag_path, args: ["welcome_modal"], method: :get
  guard_incorrect_token! :internal_seen_flag_path, args: ["welcome_modal"], method: :post

  test "GET returns seen: false when flag not set" do
    get internal_seen_flag_path("welcome_modal"), as: :json

    assert_response :success
    assert_json_response({ seen: false })
  end

  test "GET returns seen: true when flag exists" do
    create(:user_seen_flag, user: @user, key: "welcome_modal")

    get internal_seen_flag_path("welcome_modal"), as: :json

    assert_response :success
    assert_json_response({ seen: true })
  end

  test "GET scopes per user" do
    other = create(:user)
    create(:user_seen_flag, user: other, key: "welcome_modal")

    get internal_seen_flag_path("welcome_modal"), as: :json

    assert_response :success
    assert_json_response({ seen: false })
  end

  test "POST marks the flag as seen" do
    assert_difference "User::SeenFlag.count", 1 do
      post internal_seen_flag_path("welcome_modal"), as: :json
    end

    assert_response :success
    assert_json_response({ seen: true })
    assert @user.seen?("welcome_modal")
  end

  test "POST is idempotent" do
    post internal_seen_flag_path("welcome_modal"), as: :json
    assert_response :success

    assert_no_difference "User::SeenFlag.count" do
      post internal_seen_flag_path("welcome_modal"), as: :json
    end

    assert_response :success
    assert_json_response({ seen: true })
  end

  test "POST calls the MarkSeen command" do
    User::SeenFlag::MarkSeen.expects(:call).with(@user, "welcome_modal")

    post internal_seen_flag_path("welcome_modal"), as: :json

    assert_response :success
  end

  test "POST returns 422 when key is invalid" do
    long_key = "x" * 101

    post internal_seen_flag_path(long_key), as: :json

    assert_json_error(:unprocessable_entity, error_type: :seen_flag_invalid,
      errors: { key: ["is too long (maximum is 100 characters)"] })
  end
end
