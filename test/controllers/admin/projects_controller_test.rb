require "test_helper"

class Admin::ProjectsControllerTest < ApplicationControllerTest
  setup do
    @admin = create(:user, :admin)
    @headers = auth_headers_for(@admin)
  end

  # Authentication and authorization guards
  guard_admin! :admin_projects_path, method: :get
  guard_admin! :admin_projects_path, method: :post
  guard_admin! :admin_project_path, args: [1], method: :get
  guard_admin! :admin_project_path, args: [1], method: :patch
  guard_admin! :admin_project_path, args: [1], method: :delete

  # INDEX tests

  test "GET index returns all projects with pagination" do
    Prosopite.finish # Stop scan before creating test data
    project1 = create(:project, title: "Calculator", slug: "calculator")
    project2 = create(:project, title: "Todo App", slug: "todo-app")

    Prosopite.scan # Resume scan for the actual request
    get admin_projects_path, headers: @headers, as: :json

    assert_response :success
    assert_json_response({
      results: SerializeAdminProjects.([project1, project2]),
      meta: {
        current_page: 1,
        total_pages: 1,
        total_count: 2
      }
    })
  end

  test "GET index filters by title" do
    Prosopite.finish
    project1 = create(:project)
    project1.update!(title: "Calculator App")
    project2 = create(:project)
    project2.update!(title: "Todo List")

    Prosopite.scan
    get admin_projects_path(title: "Calculator"), headers: @headers, as: :json

    assert_response :success
    assert_json_response({
      results: SerializeAdminProjects.([project1]),
      meta: {
        current_page: 1,
        total_pages: 1,
        total_count: 1
      }
    })
  end

  test "GET index supports pagination" do
    Prosopite.finish
    project1 = create(:project)
    project2 = create(:project)
    create(:project)

    Prosopite.scan
    get admin_projects_path(page: 1, per: 2), headers: @headers, as: :json

    assert_response :success
    assert_json_response({
      results: SerializeAdminProjects.([project1, project2]),
      meta: {
        current_page: 1,
        total_pages: 2,
        total_count: 3
      }
    })
  end

  test "GET index returns empty results when no projects exist" do
    get admin_projects_path, headers: @headers, as: :json

    assert_response :success
    assert_json_response({
      results: [],
      meta: {
        current_page: 1,
        total_pages: 0,
        total_count: 0
      }
    })
  end

  test "GET index does not use user filtering" do
    Prosopite.finish
    project_1 = create(:project, title: "Apple Project")
    project_2 = create(:project, title: "Zebra Project")

    # Create a regular user and unlock a project
    regular_user = create(:user)
    create(:user_project, user: regular_user, project: project_2)

    Prosopite.scan
    get admin_projects_path, headers: @headers, as: :json

    assert_response :success
    # Admin should see all projects ordered by title (default ordering)
    assert_json_response({
      results: SerializeAdminProjects.([project_1, project_2]),
      meta: {
        current_page: 1,
        total_pages: 1,
        total_count: 2
      }
    })
  end

  # CREATE tests

  test "POST create creates project with valid attributes" do
    project_params = {
      project: {
        title: "Calculator",
        slug: "calculator",
        description: "Build a calculator application",
        exercise_slug: "calculator-project"
      }
    }

    assert_difference "Project.count", 1 do
      post admin_projects_path, params: project_params, headers: @headers, as: :json
    end

    assert_response :created

    project = Project.last
    assert_json_response({
      project: SerializeAdminProject.(project)
    })
  end

  test "POST create returns validation error for invalid attributes" do
    project_params = {
      project: {
        title: ""
      }
    }

    assert_no_difference "Project.count" do
      post admin_projects_path, params: project_params, headers: @headers, as: :json
    end

    assert_response :unprocessable_entity
    assert_json_response({
      error: {
        type: "validation_error",
        message: /Validation failed/
      }
    })
  end

  # SHOW tests

  test "GET show returns project" do
    project = create(:project, title: "Calculator", exercise_slug: "calculator-project")

    get admin_project_path(project.id), headers: @headers, as: :json

    assert_response :success
    assert_json_response({
      project: SerializeAdminProject.(project)
    })
  end

  test "GET show returns 404 for non-existent project" do
    get admin_project_path(999_999), headers: @headers, as: :json

    assert_response :not_found
    assert_json_response({
      error: {
        type: "not_found",
        message: "Project not found"
      }
    })
  end

  # UPDATE tests

  test "PATCH update updates project with valid attributes" do
    project = create(:project, title: "Original")
    update_params = {
      project: {
        title: "Updated"
      }
    }

    patch admin_project_path(project.id), params: update_params, headers: @headers, as: :json

    assert_response :success

    project.reload
    assert_json_response({
      project: SerializeAdminProject.(project)
    })
  end

  test "PATCH update returns validation error for invalid attributes" do
    project = create(:project)
    update_params = {
      project: {
        title: ""
      }
    }

    patch admin_project_path(project.id), params: update_params, headers: @headers, as: :json

    assert_response :unprocessable_entity
    assert_json_response({
      error: {
        type: "validation_error",
        message: /Validation failed/
      }
    })
  end

  test "PATCH update returns 404 for non-existent project" do
    update_params = {
      project: {
        title: "Updated"
      }
    }

    patch admin_project_path(999_999), params: update_params, headers: @headers, as: :json

    assert_response :not_found
    assert_json_response({
      error: {
        type: "not_found",
        message: "Project not found"
      }
    })
  end

  # DESTROY tests

  test "DELETE destroy deletes project" do
    project = create(:project)

    assert_difference "Project.count", -1 do
      delete admin_project_path(project.id), headers: @headers, as: :json
    end

    assert_response :no_content
  end

  test "DELETE destroy returns 404 for non-existent project" do
    delete admin_project_path(999_999), headers: @headers, as: :json

    assert_response :not_found
    assert_json_response({
      error: {
        type: "not_found",
        message: "Project not found"
      }
    })
  end
end
