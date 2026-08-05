require "test_helper"

class Admin::LevelsControllerTest < ApplicationControllerTest
  setup do
    @admin = create(:user, :admin)
    sign_in_user(@admin)
    @course = create(:course, slug: "test-course")
  end

  # Authentication and authorization guards
  guard_admin! :admin_levels_path, args: [{ course_slug: "test-course" }], method: :get do
    create(:course, slug: "test-course")
  end
  guard_admin! :admin_levels_path, args: [{ course_slug: "test-course" }], method: :post do
    create(:course, slug: "test-course")
  end
  guard_admin! :admin_level_path, args: [{ id: 1, course_slug: "test-course" }], method: :patch do
    course = create(:course, slug: "test-course")
    create(:level, id: 1, course: course)
  end

  # CREATE tests

  test "POST create calls Level::Create command with correct params" do
    level = create(:level, course: @course)
    Level::Create.expects(:call).with do |params|
      params["slug"] == "ruby-basics" && params[:course] == @course
    end.returns(level)

    post admin_levels_path(course_slug: @course.slug),
      params: {
        level: {
          slug: "ruby-basics"
        }
      },
      as: :json

    assert_response :created
  end

  test "POST create returns created level" do
    post admin_levels_path(course_slug: @course.slug),
      params: {
        level: {
          slug: "ruby-basics"
        }
      },
      as: :json

    assert_response :created

    json = response.parsed_body
    assert_equal "ruby-basics", json["level"]["slug"]
    assert json["level"]["position"].present?
  end

  test "POST create auto-assigns position" do
    create(:level, course: @course, position: 1)
    create(:level, course: @course, position: 2)

    post admin_levels_path(course_slug: @course.slug),
      params: {
        level: {
          slug: "new-level"
        }
      },
      as: :json

    assert_response :created
    json = response.parsed_body
    assert_equal 3, json["level"]["position"]
  end

  test "POST create accepts explicit position" do
    post admin_levels_path(course_slug: @course.slug),
      params: {
        level: {
          slug: "ruby-basics",
          position: 5
        }
      },
      as: :json

    assert_response :created
    json = response.parsed_body
    assert_equal 5, json["level"]["position"]
  end

  test "POST create returns 422 for blank slug" do
    post admin_levels_path(course_slug: @course.slug),
      params: {
        level: {
          slug: ""
        }
      },
      as: :json

    assert_response :unprocessable_entity
    json = response.parsed_body
    assert_equal "validation_error", json["error"]["type"]
    assert_match(/Validation failed/, json["error"]["message"])
  end

  test "POST create returns 422 for duplicate slug" do
    create(:level, slug: "ruby-basics")

    post admin_levels_path(course_slug: @course.slug),
      params: {
        level: {
          slug: "ruby-basics"
        }
      },
      as: :json

    assert_response :unprocessable_entity
    json = response.parsed_body
    assert_equal "validation_error", json["error"]["type"]
  end

  test "POST create returns 422 for duplicate position within course" do
    create(:level, course: @course, position: 1)

    post admin_levels_path(course_slug: @course.slug),
      params: {
        level: {
          slug: "new-level",
          position: 1
        }
      },
      as: :json

    assert_response :unprocessable_entity
    json = response.parsed_body
    assert_equal "validation_error", json["error"]["type"]
  end

  test "POST create uses SerializeAdminLevel" do
    level = create(:level, course: @course)
    Level::Create.stubs(:call).returns(level)

    SerializeAdminLevel.expects(:call).with(level).returns({ id: level.id })

    post admin_levels_path(course_slug: @course.slug),
      params: {
        level: {
          slug: "test"
        }
      },
      as: :json

    assert_response :created
  end

  test "POST create returns 404 for non-existent course" do
    post admin_levels_path(course_slug: "non-existent"),
      params: {
        level: {
          slug: "test"
        }
      },
      as: :json

    assert_response :not_found
    json = response.parsed_body
    assert_equal "Course not found", json["error"]["message"]
  end

  # INDEX tests

  test "GET index returns all levels for course with pagination meta" do
    Prosopite.finish
    level_1 = create(:level, course: @course, slug: "level-1")
    level_2 = create(:level, course: @course, slug: "level-2")
    create(:level) # Different course

    Prosopite.scan
    get admin_levels_path(course_slug: @course.slug), as: :json

    assert_response :success
    assert_json_response({
      results: SerializeAdminLevels.([level_1, level_2]),
      meta: {
        current_page: 1,
        total_pages: 1,
        total_count: 2
      }
    })
  end

  test "GET index calls Level::Search with correct params including course" do
    Prosopite.finish
    levels = create_list(:level, 2, course: @course)
    Prosopite.scan
    paginated_levels = Kaminari.paginate_array(levels, total_count: 2).page(1).per(24)

    Level::Search.expects(:call).with(
      course: @course,
      slug: "basics",
      page: "2",
      per: nil
    ).returns(paginated_levels)

    get admin_levels_path(course_slug: @course.slug, slug: "basics", page: 2),
      as: :json

    assert_response :success
  end

  test "GET index filters by slug parameter" do
    create(:level, course: @course, slug: "ruby-basics")
    advanced = create(:level, course: @course, slug: "ruby-advanced")

    get admin_levels_path(course_slug: @course.slug, slug: "advanced"),
      as: :json

    assert_response :success
    json = response.parsed_body
    assert_equal 1, json["results"].length
    assert_equal advanced.id, json["results"][0]["id"]
  end

  test "GET index paginates results" do
    Prosopite.finish
    3.times { |i| create(:level, course: @course, slug: "level-#{i}") }

    Prosopite.scan
    get admin_levels_path(course_slug: @course.slug, page: 1, per: 2),
      as: :json

    assert_response :success
    json = response.parsed_body
    assert_equal 2, json["results"].length
    assert_equal 1, json["meta"]["current_page"]
    assert_equal 2, json["meta"]["total_pages"]
    assert_equal 3, json["meta"]["total_count"]
  end

  test "GET index uses SerializePaginatedCollection with SerializeAdminLevels" do
    Prosopite.finish
    levels = create_list(:level, 2, course: @course)
    paginated_levels = Kaminari.paginate_array(levels, total_count: 2).page(1).per(24)

    Level::Search.expects(:call).returns(paginated_levels)
    SerializePaginatedCollection.expects(:call).with(
      paginated_levels,
      serializer: SerializeAdminLevels
    ).returns({ results: [], meta: {} })

    Prosopite.scan
    get admin_levels_path(course_slug: @course.slug), as: :json

    assert_response :success
  end

  # UPDATE tests

  test "PATCH update calls Level::Update command with correct params" do
    level = create(:level, course: @course)
    Level::Update.expects(:call).with(
      level,
      { "milestone_email_subject" => "New Subject" }
    ).returns(level)

    patch admin_level_path(level, course_slug: @course.slug),
      params: {
        level: {
          milestone_email_subject: "New Subject"
        }
      },
      as: :json

    assert_response :success
  end

  test "PATCH update returns updated level" do
    level = create(:level, course: @course)

    patch admin_level_path(level, course_slug: @course.slug),
      params: {
        level: {
          milestone_email_subject: "New Subject"
        }
      },
      as: :json

    assert_response :success

    assert_equal "New Subject", level.reload.milestone_email_subject
  end

  test "PATCH update can update position" do
    level = create(:level, course: @course, position: 1)

    patch admin_level_path(level, course_slug: @course.slug),
      params: { level: { position: 5 } },
      as: :json

    assert_response :success
    json = response.parsed_body
    assert_equal 5, json["level"]["position"]
  end

  test "PATCH update can update slug" do
    level = create(:level, course: @course, slug: "old-slug")

    patch admin_level_path(level, course_slug: @course.slug),
      params: { level: { slug: "new-slug" } },
      as: :json

    assert_response :success
    json = response.parsed_body
    assert_equal "new-slug", json["level"]["slug"]
  end

  test "PATCH update returns 422 for validation errors" do
    level = create(:level, course: @course)

    patch admin_level_path(level, course_slug: @course.slug),
      params: {
        level: {
          slug: ""
        }
      },
      as: :json

    assert_response :unprocessable_entity
    json = response.parsed_body
    assert_equal "validation_error", json["error"]["type"]
    assert_match(/Validation failed/, json["error"]["message"])
  end

  test "PATCH update returns 404 for non-existent level" do
    patch admin_level_path(99_999, course_slug: @course.slug),
      params: { level: { title: "New" } },
      as: :json

    assert_json_error(:not_found, error_type: :level_not_found)
  end

  test "PATCH update uses SerializeAdminLevel" do
    level = create(:level, course: @course)
    Level::Update.stubs(:call).returns(level)

    SerializeAdminLevel.expects(:call).with(level).returns({ id: level.id })

    patch admin_level_path(level, course_slug: @course.slug),
      params: { level: { title: "Updated" } },
      as: :json

    assert_response :success
  end
end
