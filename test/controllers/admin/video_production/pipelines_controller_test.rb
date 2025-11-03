require "test_helper"

class Admin::VideoProduction::PipelinesControllerTest < ApplicationControllerTest
  setup do
    @admin = create(:user, :admin)
    @headers = auth_headers_for(@admin)
  end

  # Authentication and authorization guards
  guard_admin! :admin_video_production_pipelines_path, method: :get
  guard_admin! :admin_video_production_pipeline_path, args: ['test-uuid'], method: :get
  guard_admin! :admin_video_production_pipelines_path, method: :post
  guard_admin! :admin_video_production_pipeline_path, args: ['test-uuid'], method: :patch
  guard_admin! :admin_video_production_pipeline_path, args: ['test-uuid'], method: :delete

  # INDEX tests

  test "GET index returns all pipelines with pagination meta" do
    Prosopite.finish # Stop scan before creating test data
    pipeline_1 = create(:video_production_pipeline, title: "Pipeline 1")
    pipeline_2 = create(:video_production_pipeline, title: "Pipeline 2")

    Prosopite.scan # Resume scan for the actual request
    get admin_video_production_pipelines_path, headers: @headers, as: :json

    assert_response :success
    json = response.parsed_body

    assert_equal 2, json["results"].length
    assert_equal 1, json["meta"]["current_page"]
    assert_equal 1, json["meta"]["total_pages"]
    assert_equal 2, json["meta"]["total_count"]

    # Verify pipelines are returned (most recent first by default)
    assert_equal pipeline_2.uuid, json["results"][0]["uuid"]
    assert_equal pipeline_1.uuid, json["results"][1]["uuid"]
  end

  test "GET index returns empty results when no pipelines exist" do
    get admin_video_production_pipelines_path, headers: @headers, as: :json

    assert_response :success
    json = response.parsed_body
    assert_equal 0, json["results"].length
    assert_equal 0, json["meta"]["total_count"]
  end

  test "GET index orders pipelines by updated_at desc" do
    Prosopite.finish
    old_pipeline = create(:video_production_pipeline, title: "Old")
    sleep 0.01 # Ensure different timestamps
    new_pipeline = create(:video_production_pipeline, title: "New")

    Prosopite.scan
    get admin_video_production_pipelines_path, headers: @headers, as: :json

    assert_response :success
    json = response.parsed_body
    assert_equal new_pipeline.uuid, json["results"][0]["uuid"]
    assert_equal old_pipeline.uuid, json["results"][1]["uuid"]
  end

  test "GET index paginates results" do
    Prosopite.finish
    3.times { create(:video_production_pipeline) }

    Prosopite.scan
    get admin_video_production_pipelines_path(page: 1, per: 2),
      headers: @headers,
      as: :json

    assert_response :success
    json = response.parsed_body
    assert_equal 2, json["results"].length
    assert_equal 1, json["meta"]["current_page"]
    assert_equal 2, json["meta"]["total_pages"]
    assert_equal 3, json["meta"]["total_count"]
  end

  test "GET index includes pipeline metadata" do
    pipeline = create(:video_production_pipeline,
      title: "Test Pipeline",
      version: "2.0",
      config: { 'storage' => { 'bucket' => 'test-bucket' } },
      metadata: { 'totalCost' => 10.5 })

    get admin_video_production_pipelines_path, headers: @headers, as: :json

    assert_response :success
    json = response.parsed_body
    result = json["results"][0]

    assert_equal pipeline.uuid, result["uuid"]
    assert_equal "Test Pipeline", result["title"]
    assert_equal "2.0", result["version"]
    assert_equal({ 'storage' => { 'bucket' => 'test-bucket' } }, result["config"])
    assert_equal({ 'totalCost' => 10.5 }, result["metadata"])
  end

  test "GET index uses SerializePaginatedCollection with SerializeAdminVideoProductionPipelines" do
    Prosopite.finish
    create_list(:video_production_pipeline, 2)

    SerializePaginatedCollection.expects(:call).with do |collection, serializer:|
      collection.is_a?(ActiveRecord::Relation) &&
        serializer == SerializeAdminVideoProductionPipelines
    end.returns({ results: [], meta: {} })

    Prosopite.scan
    get admin_video_production_pipelines_path, headers: @headers, as: :json

    assert_response :success
  end

  # SHOW tests

  test "GET show returns pipeline with full data structure" do
    pipeline = create(:video_production_pipeline,
      title: "Full Data Pipeline",
      version: "1.5",
      config: { 'storage' => { 'bucket' => 'my-bucket' } },
      metadata: { 'totalCost' => 25.75 })

    get admin_video_production_pipeline_path(pipeline.uuid), headers: @headers, as: :json

    assert_response :success
    assert_json_response({
      pipeline: SerializeAdminVideoProductionPipeline.(pipeline)
    })
  end

  test "GET show returns 404 for non-existent pipeline" do
    get admin_video_production_pipeline_path('non-existent-uuid'), headers: @headers, as: :json

    assert_response :not_found
    assert_json_response({
      error: {
        type: "not_found",
        message: "Pipeline not found"
      }
    })
  end

  # CREATE tests

  test "POST create creates a new pipeline" do
    pipeline_params = {
      title: "New Pipeline",
      version: "1.0",
      config: { 'storage' => { 'bucket' => 'test-bucket' } },
      metadata: { 'totalCost' => 0 }
    }

    assert_difference 'VideoProduction::Pipeline.count', 1 do
      post admin_video_production_pipelines_path,
        params: { pipeline: pipeline_params },
        headers: @headers,
        as: :json
    end

    assert_response :created
    json = response.parsed_body

    assert_equal "New Pipeline", json["pipeline"]["title"]
    assert_equal "1.0", json["pipeline"]["version"]
    assert_equal({ 'storage' => { 'bucket' => 'test-bucket' } }, json["pipeline"]["config"])
    assert json["pipeline"]["uuid"].present?
  end

  test "POST create returns validation error for missing title" do
    post admin_video_production_pipelines_path,
      params: { pipeline: { version: "1.0" } },
      headers: @headers,
      as: :json

    assert_response :unprocessable_entity
    assert_json_response({
      error: {
        type: "validation_error",
        message: "Validation failed: Title can't be blank"
      }
    })
  end

  # UPDATE tests

  test "PATCH update can update title" do
    Prosopite.finish
    pipeline = create(:video_production_pipeline, title: "Original Title")

    Prosopite.scan
    patch admin_video_production_pipeline_path(pipeline.uuid),
      params: { pipeline: { title: "Updated Title" } },
      headers: @headers,
      as: :json

    assert_response :success
    json = response.parsed_body
    assert_equal "Updated Title", json["pipeline"]["title"]
  end

  test "PATCH update returns 404 for non-existent pipeline" do
    patch admin_video_production_pipeline_path('non-existent-uuid'),
      params: { pipeline: { title: "New Title" } },
      headers: @headers,
      as: :json

    assert_response :not_found
  end

  # DESTROY tests

  test "DELETE destroy deletes pipeline and cascades to nodes" do
    Prosopite.finish
    pipeline = create(:video_production_pipeline)
    create(:video_production_node, pipeline: pipeline)
    create(:video_production_node, pipeline: pipeline)

    assert_difference 'VideoProduction::Pipeline.count', -1 do
      assert_difference 'VideoProduction::Node.count', -2 do
        Prosopite.scan
        delete admin_video_production_pipeline_path(pipeline.uuid),
          headers: @headers,
          as: :json
      end
    end

    assert_response :no_content
  end

  test "DELETE destroy returns 404 for non-existent pipeline" do
    delete admin_video_production_pipeline_path('non-existent-uuid'),
      headers: @headers,
      as: :json

    assert_response :not_found
  end
end
