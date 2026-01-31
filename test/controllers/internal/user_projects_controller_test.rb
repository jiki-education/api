require "test_helper"

class Internal::UserProjectsControllerTest < ApplicationControllerTest
  setup do
    setup_user
    @project = create(:project)
  end

  # Authentication guards
  guard_incorrect_token! :internal_user_project_path, args: ["calculator"], method: :get

  # GET /v1/user_projects/:slug tests
  test "GET show returns user project progress" do
    user_project = create(:user_project, user: @current_user, project: @project)
    serialized_data = { project_slug: @project.slug, status: "started", conversation: [], data: {} }

    SerializeUserProject.expects(:call).with(user_project).returns(serialized_data)

    get internal_user_project_path(project_slug: @project.slug),
      as: :json

    assert_response :success
    assert_json_response({ user_project: serialized_data })
  end

  test "GET show returns 404 when user_project does not exist" do
    get internal_user_project_path(project_slug: @project.slug),
      as: :json

    assert_response :not_found
    assert_json_response({
      error: {
        type: "not_found",
        message: "User project not found"
      }
    })
  end

  test "GET show returns 404 for non-existent project" do
    get internal_user_project_path(project_slug: "non-existent-slug"),
      as: :json

    assert_response :not_found
    assert_json_response({
      error: {
        type: "not_found",
        message: "Project not found"
      }
    })
  end
end
