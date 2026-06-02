require "test_helper"

# Tests the ApplicationController after_action that records a user's daily
# activity and sends a once-per-day "site_visited" analytics event.
class TrackLastActiveOnTest < ApplicationControllerTest
  test "authenticated request records last_active_on" do
    user = create(:user)
    assert_nil user.data.last_active_on

    # Signing in is itself an authenticated request, so it claims today.
    setup_user(user)

    assert_equal Date.current, user.data.reload.last_active_on
  end

  test "calls Analytics::TrackLastActiveOn on authenticated requests" do
    setup_user

    Analytics::TrackLastActiveOn.expects(:call).with(@current_user)

    get internal_me_path, as: :json

    assert_response :success
  end

  test "does not track unauthenticated requests" do
    Analytics::TrackLastActiveOn.expects(:call).never

    get internal_me_path, as: :json

    assert_json_error(:unauthorized, error_type: :unauthenticated)
  end

  test "only sends site_visited once per day" do
    setup_user # the sign-in request claims today

    Analytics::TrackEvent.expects(:defer).never

    get internal_me_path, as: :json
    get internal_me_path, as: :json

    assert_response :success
  end
end
