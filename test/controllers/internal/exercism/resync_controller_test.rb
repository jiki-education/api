require "test_helper"

class Internal::Exercism::ResyncControllerTest < ApplicationControllerTest
  setup do
    setup_user(create(:user, exercism_id: "1530"))
  end

  guard_incorrect_token! :internal_exercism_resync_path, method: :post

  test "POST resync defers a per-user resync" do
    User::Exercism::ResyncUser.expects(:defer).with(@current_user)

    post internal_exercism_resync_path, as: :json

    assert_response :success
    assert_json_response({ user: SerializeUser.(@current_user) })
  end

  test "POST resync returns 422 when user has no exercism_id" do
    @current_user.update!(exercism_id: nil)
    User::Exercism::ResyncUser.expects(:defer).never

    post internal_exercism_resync_path, as: :json

    assert_response :unprocessable_entity
  end
end
