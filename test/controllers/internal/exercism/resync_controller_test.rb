require "test_helper"

class Internal::Exercism::ResyncControllerTest < ApplicationControllerTest
  setup do
    setup_user(create(:user, exercism_id: "1530"))
  end

  guard_incorrect_token! :internal_exercism_resync_path, method: :post

  test "POST resync enqueues a per-user resync job" do
    assert_enqueued_with(job: User::Exercism::ResyncUserJob, args: [@current_user]) do
      post internal_exercism_resync_path, as: :json
    end

    assert_response :success
    assert_json_response({ user: SerializeUser.(@current_user) })
  end

  test "POST resync returns 422 when user has no exercism_id" do
    @current_user.update!(exercism_id: nil)

    assert_no_enqueued_jobs only: User::Exercism::ResyncUserJob do
      post internal_exercism_resync_path, as: :json
    end

    assert_response :unprocessable_entity
  end
end
