require "test_helper"

class Internal::ProjectsControllerTest < ApplicationControllerTest
  setup do
    setup_user
  end

  # Authentication guards
  guard_incorrect_token! :internal_projects_path, method: :get
  guard_incorrect_token! :internal_project_path, method: :get, args: ["test-project"]

  # GET /v1/projects (index) tests
  test "GET index returns projects with unlocked first, then locked" do
    Prosopite.finish
    project_zebra = create(:project, title: "Zebra Project")
    create(:project, title: "Apple Project")
    project_middle = create(:project, title: "Middle Project")

    # Unlock Zebra and Middle for current user
    create(:user_project, user: @current_user, project: project_zebra)
    create(:user_project, user: @current_user, project: project_middle)

    get internal_projects_path, headers: @headers, as: :json

    assert_response :success
    response_json = JSON.parse(response.body, symbolize_names: true)

    assert_equal 3, response_json[:results].size
    # Unlocked first (Middle, Zebra), then locked (Apple)
    assert_equal "Middle Project", response_json[:results][0][:title]
    assert_equal "Zebra Project", response_json[:results][1][:title]
    assert_equal "Apple Project", response_json[:results][2][:title]

    # Verify status fields
    assert_equal "unlocked", response_json[:results][0][:status]
    assert_equal "unlocked", response_json[:results][1][:status]
    assert_equal "locked", response_json[:results][2][:status]
  end

  test "GET index returns all projects when user has none unlocked" do
    Prosopite.finish
    create(:project, title: "Apple Project")
    create(:project, title: "Banana Project")

    get internal_projects_path, headers: @headers, as: :json

    assert_response :success
    response_json = JSON.parse(response.body, symbolize_names: true)

    assert_equal 2, response_json[:results].size
    # All locked, ordered by title
    assert_equal "Apple Project", response_json[:results][0][:title]
    assert_equal "Banana Project", response_json[:results][1][:title]
    assert_equal "locked", response_json[:results][0][:status]
    assert_equal "locked", response_json[:results][1][:status]
  end

  test "GET index shows started status" do
    Prosopite.finish
    project = create(:project, title: "Calculator")
    create(:user_project, user: @current_user, project:, started_at: Time.current, completed_at: nil)

    get internal_projects_path, headers: @headers, as: :json

    assert_response :success
    response_json = JSON.parse(response.body, symbolize_names: true)

    assert_equal 1, response_json[:results].size
    assert_equal "started", response_json[:results][0][:status]
  end

  test "GET index shows completed status" do
    Prosopite.finish
    project = create(:project, title: "Calculator")
    create(:user_project, user: @current_user, project:, started_at: 2.days.ago, completed_at: Time.current)

    get internal_projects_path, headers: @headers, as: :json

    assert_response :success
    response_json = JSON.parse(response.body, symbolize_names: true)

    assert_equal 1, response_json[:results].size
    assert_equal "completed", response_json[:results][0][:status]
  end

  test "GET index filters by title parameter" do
    Prosopite.finish
    create(:project, title: "Calculator App")
    create(:project, title: "Todo List")
    project_3 = create(:project, title: "Scientific Calculator")

    create(:user_project, user: @current_user, project: project_3)

    get internal_projects_path(title: "Calculator"), headers: @headers, as: :json

    assert_response :success
    response_json = JSON.parse(response.body, symbolize_names: true)

    assert_equal 2, response_json[:results].size
    # Scientific Calculator (unlocked) first, then Calculator App (locked)
    assert_equal "Scientific Calculator", response_json[:results][0][:title]
    assert_equal "Calculator App", response_json[:results][1][:title]
  end

  test "GET index supports pagination with page parameter" do
    Prosopite.finish
    create(:project, title: "Apple")
    create(:project, title: "Banana")
    project_3 = create(:project, title: "Cherry")

    create(:user_project, user: @current_user, project: project_3)

    get internal_projects_path(page: 1, per: 2), headers: @headers, as: :json

    assert_response :success
    response_json = JSON.parse(response.body, symbolize_names: true)

    assert_equal 2, response_json[:results].size
    assert_equal 1, response_json[:meta][:current_page]
    assert_equal 3, response_json[:meta][:total_count]
    assert_equal 2, response_json[:meta][:total_pages]
  end

  test "GET index supports pagination with per parameter" do
    Prosopite.finish
    5.times { |i| create(:project, title: "Project #{i}") }

    get internal_projects_path(per: 3), headers: @headers, as: :json

    assert_response :success
    response_json = JSON.parse(response.body, symbolize_names: true)

    assert_equal 3, response_json[:results].size
  end

  test "GET index returns correct fields" do
    Prosopite.finish
    create(:project, slug: "calculator", title: "Calculator", description: "Build a calculator")

    get internal_projects_path, headers: @headers, as: :json

    assert_response :success
    response_json = JSON.parse(response.body, symbolize_names: true)

    result = response_json[:results][0]
    assert_includes result.keys, :title
    assert_includes result.keys, :slug
    assert_includes result.keys, :description
    assert_includes result.keys, :status
  end

  # GET /v1/projects/:slug (show) tests
  test "GET show returns project by slug" do
    Prosopite.finish
    project = create(:project, slug: "calculator", title: "Calculator", description: "Build a calculator")

    get internal_project_path(project_slug: project.slug), headers: @headers, as: :json

    assert_response :success
    assert_json_response({
      project: SerializeProject.(project)
    })
  end

  test "GET show returns 404 for non-existent project" do
    Prosopite.finish

    get internal_project_path(project_slug: "non-existent"), headers: @headers, as: :json

    assert_response :not_found
    response_json = JSON.parse(response.body, symbolize_names: true)
    assert_equal "not_found", response_json[:error][:type]
    assert_equal "Project not found", response_json[:error][:message]
  end
end
