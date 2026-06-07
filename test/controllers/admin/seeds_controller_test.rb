require "test_helper"

class Admin::SeedsControllerTest < ApplicationControllerTest
  setup do
    @admin = create(:user, :admin)
    sign_in_user(@admin)
  end

  guard_admin! :admin_seeds_path, method: :post

  test "POST create runs seeds and returns success" do
    Rails.application.expects(:load_seed)

    post admin_seeds_path, as: :json

    assert_response :ok
    assert_json_response({ success: true })
  end
end
