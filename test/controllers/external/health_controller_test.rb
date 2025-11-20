require "test_helper"

class External::HealthControllerTest < ActionDispatch::IntegrationTest
  test "GET check returns user handle when users exist" do
    create(:user, handle: "test_user")

    get health_check_path, as: :json

    assert_response :success
    assert_json_response({
      ruok: true,
      sanity_data: {
        user: "test_user"
      }
    })
  end

  test "GET check returns no_users when no users exist" do
    User.destroy_all

    get health_check_path, as: :json

    assert_response :success
    assert_json_response({
      ruok: true,
      sanity_data: {
        user: "no_users"
      }
    })
  end
end
