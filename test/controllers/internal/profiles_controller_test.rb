require "test_helper"

class Internal::ProfilesControllerTest < ApplicationControllerTest
  setup do
    @user = create(:user)
    sign_in_user(@user)
  end

  guard_incorrect_token! :internal_profile_path, method: :get

  test "GET show returns profile data with current_streak when streaks enabled" do
    @user.data.update!(streaks_enabled: true)
    @user.activity_data.update!(
      current_streak: 7,
      activity_days: { Date.current.to_s => User::ActivityData::ACTIVITY_PRESENT }
    )

    get internal_profile_path, as: :json

    assert_response :success

    json = response.parsed_body
    assert json["profile"]["streaks_enabled"]
    assert_equal 7, json["profile"]["current_streak"]
    refute json["profile"].key?("total_active_days")
  end

  test "GET show returns profile data with total_active_days when streaks disabled" do
    @user.data.update!(streaks_enabled: false)
    @user.activity_data.update!(
      total_active_days: 15,
      activity_days: { Date.current.to_s => User::ActivityData::ACTIVITY_PRESENT }
    )

    get internal_profile_path, as: :json

    assert_response :success

    json = response.parsed_body
    refute json["profile"]["streaks_enabled"]
    assert_equal 15, json["profile"]["total_active_days"]
    refute json["profile"].key?("current_streak")
  end
end
