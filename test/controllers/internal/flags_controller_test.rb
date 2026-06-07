require "test_helper"

class Internal::FlagsControllerTest < ApplicationControllerTest
  setup do
    @user = create(:user)
    sign_in_user(@user)
  end

  guard_incorrect_token! :internal_flag_path, args: ["welcome_modal"], method: :get
  guard_incorrect_token! :internal_flag_path, args: ["welcome_modal"], method: :post

  test "GET returns flagged: false when flag not set" do
    get internal_flag_path("welcome_modal"), as: :json

    assert_response :success
    assert_json_response({ flagged: false })
  end

  test "GET returns flagged: true when flag exists" do
    create(:user_flag, user: @user, key: "client:welcome_modal")

    get internal_flag_path("welcome_modal"), as: :json

    assert_response :success
    assert_json_response({ flagged: true })
  end

  test "GET scopes per user" do
    other = create(:user)
    create(:user_flag, user: other, key: "client:welcome_modal")

    get internal_flag_path("welcome_modal"), as: :json

    assert_response :success
    assert_json_response({ flagged: false })
  end

  test "POST marks the flag" do
    assert_difference "User::Flag.count", 1 do
      post internal_flag_path("welcome_modal"), as: :json
    end

    assert_response :success
    assert_json_response({ flagged: true })
    assert @user.flagged?("client:welcome_modal")
  end

  test "POST is idempotent" do
    post internal_flag_path("welcome_modal"), as: :json
    assert_response :success

    assert_no_difference "User::Flag.count" do
      post internal_flag_path("welcome_modal"), as: :json
    end

    assert_response :success
    assert_json_response({ flagged: true })
  end

  test "POST calls Mark with the namespaced key" do
    User::Flag::Mark.expects(:call).with(@user, "client:welcome_modal")

    post internal_flag_path("welcome_modal"), as: :json

    assert_response :success
  end

  test "POST returns 422 when key is invalid" do
    # The namespaced key is "client:" + 94 chars = 101 chars, exceeding the 100-char limit.
    long_key = "x" * 94

    post internal_flag_path(long_key), as: :json

    assert_json_error(:unprocessable_entity, error_type: :flag_invalid,
      errors: { key: ["is too long (maximum is 100 characters)"] })
  end

  test "GET cannot read server-controlled flags" do
    create(:user_flag, user: @user, key: "email:welcome_sent")

    get internal_flag_path("email:welcome_sent"), as: :json

    # The FE asking for "email:welcome_sent" looks up "client:email:welcome_sent",
    # which doesn't exist — server flags are unreachable from the FE.
    assert_response :success
    assert_json_response({ flagged: false })
  end
end
