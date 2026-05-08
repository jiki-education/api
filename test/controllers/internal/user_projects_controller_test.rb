require "test_helper"

class Internal::UserProjectsControllerTest < ApplicationControllerTest
  setup do
    setup_user
    @current_user.data.update!(membership_type: "premium")
    @project = create(:project)
  end

  # Authentication guards
  guard_incorrect_token! :internal_user_project_path, args: ["calculator"], method: :get
  guard_incorrect_token! :complete_internal_user_project_path, args: ["calculator"], method: :patch

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

    assert_json_error(:not_found, error_type: :user_project_not_found)
  end

  test "GET show returns 404 for non-existent project" do
    get internal_user_project_path(project_slug: "non-existent-slug"),
      as: :json

    assert_json_error(:not_found, error_type: :project_not_found)
  end

  test "GET show returns 403 for non-premium user" do
    @current_user.data.update!(membership_type: "standard")

    get internal_user_project_path(project_slug: @project.slug),
      as: :json

    assert_json_error(:forbidden, error_type: :premium_required)
  end

  # PATCH /v1/user_projects/:slug/complete tests
  test "PATCH complete successfully completes a project" do
    create(:user_project, user: @current_user, project: @project)

    patch complete_internal_user_project_path(project_slug: @project.slug),
      as: :json

    assert_response :success
    assert_json_response({})
  end

  test "PATCH complete delegates to UserProject::Complete command" do
    user_project = create(:user_project, user: @current_user, project: @project)
    UserProject::Complete.expects(:call).with(user_project)

    patch complete_internal_user_project_path(project_slug: @project.slug),
      as: :json

    assert_response :success
  end

  test "PATCH complete returns 404 for non-existent project" do
    patch complete_internal_user_project_path(project_slug: "non-existent-slug"),
      as: :json

    assert_json_error(:not_found, error_type: :project_not_found)
  end

  test "PATCH complete returns 422 when project not started" do
    patch complete_internal_user_project_path(project_slug: @project.slug),
      as: :json

    assert_json_error(:unprocessable_entity, error_type: :user_project_not_found)
  end

  test "PATCH complete is idempotent" do
    create(:user_project, user: @current_user, project: @project)

    patch complete_internal_user_project_path(project_slug: @project.slug),
      as: :json

    assert_response :success

    assert_no_difference "UserProject.count" do
      patch complete_internal_user_project_path(project_slug: @project.slug),
        as: :json
    end

    assert_response :success
  end
end
