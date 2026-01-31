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
    project_apple = create(:project, title: "Apple Project")
    project_middle = create(:project, title: "Middle Project")

    # Unlock Zebra and Middle for current user
    create(:user_project, user: @current_user, project: project_zebra)
    create(:user_project, user: @current_user, project: project_middle)

    get internal_projects_path, as: :json

    assert_response :success
    # Unlocked first (Middle, Zebra), then locked (Apple)
    assert_json_response({
      results: SerializeProjects.([project_middle, project_zebra, project_apple], for_user: @current_user),
      meta: {
        current_page: 1,
        total_pages: 1,
        total_count: 3,
        events: []
      }
    })
  end

  test "GET index returns all projects when user has none unlocked" do
    Prosopite.finish
    project_apple = create(:project, title: "Apple Project")
    project_banana = create(:project, title: "Banana Project")

    get internal_projects_path, as: :json

    assert_response :success
    # All locked, ordered by title
    assert_json_response({
      results: SerializeProjects.([project_apple, project_banana], for_user: @current_user),
      meta: {
        current_page: 1,
        total_pages: 1,
        total_count: 2,
        events: []
      }
    })
  end

  test "GET index shows started status" do
    Prosopite.finish
    project = create(:project, title: "Calculator")
    create(:user_project, user: @current_user, project:, started_at: Time.current, completed_at: nil)

    get internal_projects_path, as: :json

    assert_response :success
    assert_json_response({
      results: SerializeProjects.([project], for_user: @current_user),
      meta: {
        current_page: 1,
        total_pages: 1,
        total_count: 1,
        events: []
      }
    })
  end

  test "GET index shows completed status" do
    Prosopite.finish
    project = create(:project, title: "Calculator")
    create(:user_project, user: @current_user, project:, started_at: 2.days.ago, completed_at: Time.current)

    get internal_projects_path, as: :json

    assert_response :success
    assert_json_response({
      results: SerializeProjects.([project], for_user: @current_user),
      meta: {
        current_page: 1,
        total_pages: 1,
        total_count: 1,
        events: []
      }
    })
  end

  test "GET index filters by title parameter" do
    Prosopite.finish
    project_calc_app = create(:project, title: "Calculator App")
    create(:project, title: "Todo List")
    project_sci_calc = create(:project, title: "Scientific Calculator")

    create(:user_project, user: @current_user, project: project_sci_calc)

    get internal_projects_path(title: "Calculator"), as: :json

    assert_response :success
    # Scientific Calculator (unlocked) first, then Calculator App (locked)
    assert_json_response({
      results: SerializeProjects.([project_sci_calc, project_calc_app], for_user: @current_user),
      meta: {
        current_page: 1,
        total_pages: 1,
        total_count: 2,
        events: []
      }
    })
  end

  test "GET index supports pagination with page parameter" do
    Prosopite.finish
    project_apple = create(:project, title: "Apple")
    create(:project, title: "Banana")
    project_cherry = create(:project, title: "Cherry")

    create(:user_project, user: @current_user, project: project_cherry)

    get internal_projects_path(page: 1, per: 2), as: :json

    assert_response :success
    assert_json_response({
      results: SerializeProjects.([project_cherry, project_apple], for_user: @current_user),
      meta: {
        current_page: 1,
        total_pages: 2,
        total_count: 3,
        events: []
      }
    })
  end

  test "GET index supports pagination with per parameter" do
    Prosopite.finish
    projects = Array.new(5) { |i| create(:project, title: "Project #{i}") }

    get internal_projects_path(per: 3), as: :json

    assert_response :success
    assert_json_response({
      results: SerializeProjects.(projects.first(3), for_user: @current_user),
      meta: {
        current_page: 1,
        total_pages: 2,
        total_count: 5,
        events: []
      }
    })
  end

  test "GET index returns correct fields" do
    Prosopite.finish
    project = create(:project, slug: "calculator", title: "Calculator", description: "Build a calculator")

    get internal_projects_path, as: :json

    assert_response :success
    assert_json_response({
      results: SerializeProjects.([project], for_user: @current_user),
      meta: {
        current_page: 1,
        total_pages: 1,
        total_count: 1,
        events: []
      }
    })
  end

  # GET /v1/projects/:slug (show) tests
  test "GET show returns project by slug" do
    Prosopite.finish
    project = create(:project, slug: "calculator", title: "Calculator", description: "Build a calculator")

    get internal_project_path(project_slug: project.slug), as: :json

    assert_response :success
    assert_json_response({
      project: SerializeProject.(project)
    })
  end

  test "GET show returns 404 for non-existent project" do
    Prosopite.finish

    get internal_project_path(project_slug: "non-existent"), as: :json

    assert_response :not_found
    assert_json_response({
      error: {
        type: "not_found",
        message: "Project not found"
      }
    })
  end
end
