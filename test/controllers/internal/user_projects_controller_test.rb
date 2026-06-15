require "test_helper"

class Internal::UserProjectsControllerTest < ApplicationControllerTest
  setup do
    setup_user
    make_premium(@current_user)
    @project = create(:project)
  end

  # Authentication guards
  guard_incorrect_token! :internal_user_project_path, args: ["calculator"], method: :get
  guard_incorrect_token! :start_internal_user_project_path, args: ["calculator"], method: :post
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
    make_non_premium(@current_user)

    get internal_user_project_path(project_slug: @project.slug),
      as: :json

    assert_json_error(:forbidden, error_type: :premium_required)
  end

  # POST /v1/user_projects/:slug/start tests
  test "POST start creates and starts the user project" do
    freeze_time do
      post start_internal_user_project_path(project_slug: @project.slug),
        as: :json

      assert_response :success
      assert_json_response({})

      user_project = UserProject.find_by!(user: @current_user, project: @project)
      assert_equal Time.current, user_project.started_at
    end
  end

  test "POST start delegates to UserProject::Start command" do
    UserProject::Start.expects(:call).with(@current_user, @project)

    post start_internal_user_project_path(project_slug: @project.slug),
      as: :json

    assert_response :success
  end

  test "POST start is idempotent" do
    post start_internal_user_project_path(project_slug: @project.slug), as: :json
    original_started_at = UserProject.find_by!(user: @current_user, project: @project).started_at

    travel 1.hour do
      post start_internal_user_project_path(project_slug: @project.slug), as: :json
      assert_response :success
    end

    assert_equal original_started_at,
      UserProject.find_by!(user: @current_user, project: @project).started_at
  end

  test "POST start returns 404 for non-existent project" do
    post start_internal_user_project_path(project_slug: "non-existent-slug"),
      as: :json

    assert_json_error(:not_found, error_type: :project_not_found)
  end

  test "POST start returns 403 for non-premium user" do
    make_non_premium(@current_user)

    post start_internal_user_project_path(project_slug: @project.slug),
      as: :json

    assert_json_error(:forbidden, error_type: :premium_required)
  end

  test "POST start returns 403 when project is locked" do
    lesson = create(:lesson, :exercise)
    @project.update!(unlocked_by_lesson: lesson)

    post start_internal_user_project_path(project_slug: @project.slug),
      as: :json

    assert_json_error(:forbidden, error_type: :project_locked)
    assert_equal 0, UserProject.count
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

  test "PATCH complete returns 404 when project not started" do
    patch complete_internal_user_project_path(project_slug: @project.slug),
      as: :json

    assert_json_error(:not_found, error_type: :user_project_not_found)
  end

  test "PATCH complete returns 403 for non-premium user" do
    make_non_premium(@current_user)

    patch complete_internal_user_project_path(project_slug: @project.slug),
      as: :json

    assert_json_error(:forbidden, error_type: :premium_required)
  end

  test "PATCH complete is idempotent" do
    user_project = create(:user_project, user: @current_user, project: @project)

    freeze_time do
      patch complete_internal_user_project_path(project_slug: @project.slug),
        as: :json

      assert_response :success
      assert_equal Time.current, user_project.reload.completed_at
    end

    original_completed_at = user_project.completed_at

    travel 1.hour do
      patch complete_internal_user_project_path(project_slug: @project.slug),
        as: :json

      assert_response :success
    end

    assert_equal original_completed_at, user_project.reload.completed_at
  end
end
