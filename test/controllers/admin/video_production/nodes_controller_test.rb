require "test_helper"

class Admin::VideoProduction::NodesControllerTest < ApplicationControllerTest
  setup do
    @admin = create(:user, :admin)
    @headers = auth_headers_for(@admin)
    @pipeline = create(:video_production_pipeline)
  end

  # Authentication and authorization guards
  guard_admin! :admin_video_production_pipeline_nodes_path, args: ['test-uuid'], method: :get
  guard_admin! :admin_video_production_pipeline_node_path, args: %w[test-uuid node-uuid], method: :get
  guard_admin! :admin_video_production_pipeline_nodes_path, args: ['test-uuid'], method: :post
  guard_admin! :admin_video_production_pipeline_node_path, args: %w[test-uuid node-uuid], method: :patch
  guard_admin! :admin_video_production_pipeline_node_path, args: %w[test-uuid node-uuid], method: :delete
  guard_admin! :execute_admin_video_production_pipeline_node_path, args: %w[test-uuid node-uuid], method: :post
  guard_admin! :output_admin_video_production_pipeline_node_path, args: %w[test-uuid node-uuid], method: :get

  # INDEX tests

  test "GET index returns all nodes for a pipeline" do
    Prosopite.finish
    node_1 = create(:video_production_node, pipeline: @pipeline, title: "Node 1")
    node_2 = create(:video_production_node, pipeline: @pipeline, title: "Node 2")

    Prosopite.scan
    get admin_video_production_pipeline_nodes_path(@pipeline.uuid), headers: @headers, as: :json

    assert_response :success
    json = response.parsed_body

    assert_equal 2, json["nodes"].length
    assert_equal node_1.uuid, json["nodes"][0]["uuid"]
    assert_equal "Node 1", json["nodes"][0]["title"]
    assert_equal node_2.uuid, json["nodes"][1]["uuid"]
    assert_equal "Node 2", json["nodes"][1]["title"]
  end

  test "GET index returns empty array when pipeline has no nodes" do
    get admin_video_production_pipeline_nodes_path(@pipeline.uuid), headers: @headers, as: :json

    assert_response :success
    json = response.parsed_body
    assert_equal 0, json["nodes"].length
  end

  test "GET index returns 404 for non-existent pipeline" do
    get admin_video_production_pipeline_nodes_path('non-existent-uuid'), headers: @headers, as: :json

    assert_response :not_found
    assert_json_response({
      error: {
        type: "not_found",
        message: "Pipeline not found"
      }
    })
  end

  test "GET index includes full node data" do
    Prosopite.finish
    input1 = create(:video_production_node, pipeline: @pipeline)
    input2 = create(:video_production_node, pipeline: @pipeline)
    node = create(:video_production_node,
      pipeline: @pipeline,
      title: "Test Node",
      type: "merge-videos",
      status: "pending",
      inputs: { 'segments' => [input1.uuid, input2.uuid] },
      config: { 'provider' => 'ffmpeg' },
      metadata: { 'cost' => 0.05 },
      output: { 's3Key' => 'output.mp4' })

    Prosopite.scan
    get admin_video_production_pipeline_nodes_path(@pipeline.uuid), headers: @headers, as: :json

    assert_response :success
    json = response.parsed_body

    # Find the merge-videos node (nodes ordered by created_at, so it's last)
    node_data = json["nodes"].find { |n| n["type"] == "merge-videos" }
    assert node_data.present?, "Should find merge-videos node in response"

    assert_equal "Test Node", node_data["title"]
    assert_equal "merge-videos", node_data["type"]
    assert_equal "pending", node_data["status"]
    assert_equal({ 'segments' => [input1.uuid, input2.uuid] }, node_data["inputs"])
    assert_equal({ 'provider' => 'ffmpeg' }, node_data["config"])
    assert_equal({ 'cost' => 0.05 }, node_data["metadata"])
    assert_equal({ 's3Key' => 'output.mp4' }, node_data["output"])
    # Validation state fields are present (values depend on Create vs factory)
    assert node_data.key?("is_valid")
    assert node_data.key?("validation_errors")
    assert_equal node.uuid, node_data["uuid"]
    assert_equal @pipeline.uuid, node_data["pipeline_uuid"]
  end

  test "GET index orders nodes by created_at" do
    Prosopite.finish
    node_2 = create(:video_production_node, pipeline: @pipeline, title: "Second")
    node_1 = create(:video_production_node, pipeline: @pipeline, title: "First")
    # Update first node to make it most recently updated but still first by creation
    node_1.update!(title: "First Updated")

    Prosopite.scan
    get admin_video_production_pipeline_nodes_path(@pipeline.uuid), headers: @headers, as: :json

    assert_response :success
    json = response.parsed_body
    assert_equal node_2.uuid, json["nodes"][0]["uuid"]
    assert_equal node_1.uuid, json["nodes"][1]["uuid"]
  end

  test "GET index does not return nodes from other pipelines" do
    Prosopite.finish
    other_pipeline = create(:video_production_pipeline)
    node_in_pipeline = create(:video_production_node, pipeline: @pipeline)
    create(:video_production_node, pipeline: other_pipeline)

    Prosopite.scan
    get admin_video_production_pipeline_nodes_path(@pipeline.uuid), headers: @headers, as: :json

    assert_response :success
    json = response.parsed_body
    assert_equal 1, json["nodes"].length
    assert_equal node_in_pipeline.uuid, json["nodes"][0]["uuid"]
  end

  # SHOW tests

  test "GET show returns single node with full data" do
    audio_node = create(:video_production_node, pipeline: @pipeline, type: 'generate-voiceover')
    node = create(:video_production_node,
      pipeline: @pipeline,
      title: "Test Node",
      type: "generate-talking-head",
      status: "in_progress",
      inputs: { 'audio' => [audio_node.uuid] },
      config: { 'provider' => 'heygen', 'avatarId' => 'avatar-1' },
      metadata: { 'started_at' => Time.current.iso8601 },
      output: nil)

    get admin_video_production_pipeline_node_path(@pipeline.uuid, node.uuid),
      headers: @headers,
      as: :json

    assert_response :success
    assert_json_response({
      node: SerializeAdminVideoProductionNode.(node)
    })
  end

  test "GET show returns node with asset type" do
    node = create(:video_production_node,
      pipeline: @pipeline,
      type: "asset",
      asset: { 'source' => 'videos/intro.mp4', 'type' => 'video' })

    get admin_video_production_pipeline_node_path(@pipeline.uuid, node.uuid),
      headers: @headers,
      as: :json

    assert_response :success
    json = response.parsed_body
    assert_equal "asset", json["node"]["type"]
    assert_equal({ 'source' => 'videos/intro.mp4', 'type' => 'video' }, json["node"]["asset"])
  end

  test "GET show returns completed node with output" do
    node = create(:video_production_node, :completed,
      pipeline: @pipeline,
      status: "completed",
      metadata: {
        'started_at' => 1.hour.ago.iso8601,
        'completed_at' => Time.current.iso8601,
        'cost' => 0.15
      },
      output: {
        'type' => 'video',
        's3Key' => 'pipelines/xyz/nodes/abc/output.mp4',
        'duration' => 120.5,
        'size' => 10_485_760
      })

    get admin_video_production_pipeline_node_path(@pipeline.uuid, node.uuid),
      headers: @headers,
      as: :json

    assert_response :success
    json = response.parsed_body
    assert_equal "completed", json["node"]["status"]
    assert json["node"]["metadata"]["completed_at"].present?
    assert_equal 0.15, json["node"]["metadata"]["cost"]
    assert_equal "video", json["node"]["output"]["type"]
    assert_equal "pipelines/xyz/nodes/abc/output.mp4", json["node"]["output"]["s3Key"]
  end

  test "GET show returns 404 for non-existent pipeline" do
    get admin_video_production_pipeline_node_path('non-existent-uuid', 'some-node-uuid'),
      headers: @headers,
      as: :json

    assert_response :not_found
    assert_json_response({
      error: {
        type: "not_found",
        message: "Pipeline not found"
      }
    })
  end

  test "GET show returns 404 for non-existent node" do
    get admin_video_production_pipeline_node_path(@pipeline.uuid, 'non-existent-node-uuid'),
      headers: @headers,
      as: :json

    assert_response :not_found
    assert_json_response({
      error: {
        type: "not_found",
        message: "Node not found"
      }
    })
  end

  test "GET show returns 404 when node belongs to different pipeline" do
    other_pipeline = create(:video_production_pipeline)
    node_in_other = create(:video_production_node, pipeline: other_pipeline)

    get admin_video_production_pipeline_node_path(@pipeline.uuid, node_in_other.uuid),
      headers: @headers,
      as: :json

    assert_response :not_found
    assert_json_response({
      error: {
        type: "not_found",
        message: "Node not found"
      }
    })
  end

  # CREATE tests

  test "POST create creates a new node" do
    Prosopite.finish
    input1 = create(:video_production_node, pipeline: @pipeline)
    input2 = create(:video_production_node, pipeline: @pipeline)

    node_params = {
      title: "New Node",
      type: "merge-videos",
      inputs: { 'segments' => [input1.uuid, input2.uuid] },
      config: { 'provider' => 'ffmpeg' }
    }

    assert_difference 'VideoProduction::Node.count', 1 do
      Prosopite.scan
      post admin_video_production_pipeline_nodes_path(@pipeline.uuid),
        params: { node: node_params },
        headers: @headers,
        as: :json
    end

    assert_response :created
    json = response.parsed_body

    assert_equal "New Node", json["node"]["title"]
    assert_equal "merge-videos", json["node"]["type"]
    assert_equal "pending", json["node"]["status"]
    assert_equal({ 'segments' => [input1.uuid, input2.uuid] }, json["node"]["inputs"])
    assert_equal({ 'provider' => 'ffmpeg' }, json["node"]["config"])
    assert json["node"]["uuid"].present?
  end

  test "POST create allows invalid nodes to be created" do
    # merge-videos requires at least 2 segments, but node is still created
    node_params = {
      title: "Invalid Node",
      type: "merge-videos",
      inputs: { 'segments' => ['only-one'] },
      config: { 'provider' => 'ffmpeg' }
    }

    post admin_video_production_pipeline_nodes_path(@pipeline.uuid),
      params: { node: node_params },
      headers: @headers,
      as: :json

    assert_response :created
    json = response.parsed_body
    assert_equal "Invalid Node", json["node"]["title"]
    assert_equal "merge-videos", json["node"]["type"]
  end

  test "POST create returns validation state for invalid node" do
    node_params = {
      title: "Invalid Node",
      type: "merge-videos",
      inputs: { 'segments' => ['only-one'] }, # Invalid: requires at least 2 segments
      config: { 'provider' => 'ffmpeg' }
    }

    post admin_video_production_pipeline_nodes_path(@pipeline.uuid),
      params: { node: node_params },
      headers: @headers,
      as: :json

    assert_response :created
    json = response.parsed_body

    # Node created but marked as invalid
    refute json["node"]["is_valid"]
    assert json["node"]["validation_errors"].present?
    assert json["node"]["validation_errors"]["segments"].present?
    assert_match(/requires at least 2 items/, json["node"]["validation_errors"]["segments"])
  end

  test "POST create returns validation state for valid node" do
    input1 = create(:video_production_node, pipeline: @pipeline)
    input2 = create(:video_production_node, pipeline: @pipeline)

    node_params = {
      title: "Valid Node",
      type: "merge-videos",
      inputs: { 'segments' => [input1.uuid, input2.uuid] },
      config: { 'provider' => 'ffmpeg' }
    }

    post admin_video_production_pipeline_nodes_path(@pipeline.uuid),
      params: { node: node_params },
      headers: @headers,
      as: :json

    assert_response :created
    json = response.parsed_body

    # Node is valid
    assert json["node"]["is_valid"]
    assert_empty(json["node"]["validation_errors"])
  end

  test "POST create returns validation errors for non-existent node references" do
    node_params = {
      title: "Invalid References",
      type: "merge-videos",
      inputs: { 'segments' => %w[fake-uuid-1 fake-uuid-2] },
      config: { 'provider' => 'ffmpeg' }
    }

    post admin_video_production_pipeline_nodes_path(@pipeline.uuid),
      params: { node: node_params },
      headers: @headers,
      as: :json

    assert_response :created
    json = response.parsed_body

    refute json["node"]["is_valid"]
    assert json["node"]["validation_errors"]["segments"].present?
    assert_match(/references non-existent nodes/, json["node"]["validation_errors"]["segments"])
  end

  test "POST create returns 404 for non-existent pipeline" do
    post admin_video_production_pipeline_nodes_path('non-existent-uuid'),
      params: { node: { title: "Node", type: "asset" } },
      headers: @headers,
      as: :json

    assert_response :not_found
  end

  # UPDATE tests

  test "PATCH update updates node fields" do
    Prosopite.finish
    input3 = create(:video_production_node, pipeline: @pipeline)
    input4 = create(:video_production_node, pipeline: @pipeline)
    node = create(:video_production_node,
      pipeline: @pipeline,
      type: "merge-videos",
      inputs: { 'segments' => [input3.uuid, input4.uuid] },
      config: { 'provider' => 'ffmpeg' })

    new_input1 = create(:video_production_node, pipeline: @pipeline)
    new_input2 = create(:video_production_node, pipeline: @pipeline)

    Prosopite.scan
    patch admin_video_production_pipeline_node_path(@pipeline.uuid, node.uuid),
      params: {
        node: {
          inputs: { 'segments' => [new_input1.uuid, new_input2.uuid] },
          config: { 'provider' => 'updated-ffmpeg', 'new_key' => 'new_value' }
        }
      },
      headers: @headers,
      as: :json

    assert_response :success
    json = response.parsed_body

    # Fields are replaced with new values
    assert_equal({ 'segments' => [new_input1.uuid, new_input2.uuid] }, json["node"]["inputs"])
    assert_equal({ 'provider' => 'updated-ffmpeg', 'new_key' => 'new_value' }, json["node"]["config"])
  end

  test "PATCH update resets status to pending when structure changes" do
    Prosopite.finish
    input1 = create(:video_production_node, pipeline: @pipeline)
    input2 = create(:video_production_node, pipeline: @pipeline)
    node = create(:video_production_node,
      pipeline: @pipeline,
      type: "merge-videos",
      status: "completed",
      inputs: { 'segments' => [input1.uuid, input2.uuid] },
      config: { 'provider' => 'ffmpeg' })

    Prosopite.scan
    patch admin_video_production_pipeline_node_path(@pipeline.uuid, node.uuid),
      params: {
        node: { config: { 'provider' => 'new-provider' } }
      },
      headers: @headers,
      as: :json

    assert_response :success
    json = response.parsed_body

    # Status reset to pending because config changed
    assert_equal "pending", json["node"]["status"]
  end

  test "PATCH update does not reset status when only title changes" do
    Prosopite.finish
    node = create(:video_production_node,
      pipeline: @pipeline,
      status: "completed",
      title: "Original Title")

    Prosopite.scan
    patch admin_video_production_pipeline_node_path(@pipeline.uuid, node.uuid),
      params: { node: { title: "Updated Title" } },
      headers: @headers,
      as: :json

    assert_response :success
    json = response.parsed_body

    # Status unchanged because only title changed (not structure)
    assert_equal "completed", json["node"]["status"]
    assert_equal "Updated Title", json["node"]["title"]
  end

  test "PATCH update allows invalid nodes to be updated" do
    Prosopite.finish
    input1 = create(:video_production_node, pipeline: @pipeline, status: "completed")
    node = create(:video_production_node,
      pipeline: @pipeline,
      type: "merge-videos",
      inputs: { 'segments' => [input1.uuid, input1.uuid] })

    Prosopite.scan
    # Try to reference non-existent nodes - update succeeds but node is marked invalid
    patch admin_video_production_pipeline_node_path(@pipeline.uuid, node.uuid),
      params: {
        node: { inputs: { 'segments' => %w[non-existent-uuid-1 non-existent-uuid-2] } }
      },
      headers: @headers,
      as: :json

    assert_response :success
    json = response.parsed_body
    assert_equal %w[non-existent-uuid-1 non-existent-uuid-2], json["node"]["inputs"]["segments"]
  end

  test "PATCH update returns validation state when making node invalid" do
    Prosopite.finish
    input1 = create(:video_production_node, pipeline: @pipeline)
    input2 = create(:video_production_node, pipeline: @pipeline)

    # Use Create command to ensure validation runs
    node = VideoProduction::Node::Create.(@pipeline, {
      type: "merge-videos",
      title: "Test Node",
      config: { 'provider' => 'ffmpeg' },
      inputs: { 'segments' => [input1.uuid, input2.uuid] }
    })

    assert node.is_valid?, "Node should start as valid"

    Prosopite.scan
    # Update with invalid inputs (only 1 segment)
    patch admin_video_production_pipeline_node_path(@pipeline.uuid, node.uuid),
      params: {
        node: { inputs: { 'segments' => [input1.uuid] } }
      },
      headers: @headers,
      as: :json

    assert_response :success
    json = response.parsed_body

    # Node now invalid
    refute json["node"]["is_valid"]
    assert json["node"]["validation_errors"]["segments"].present?
    assert_match(/requires at least 2 items/, json["node"]["validation_errors"]["segments"])
  end

  test "PATCH update returns validation state when fixing invalid node" do
    Prosopite.finish
    node = create(:video_production_node,
      pipeline: @pipeline,
      type: "merge-videos",
      config: { 'provider' => 'ffmpeg' },
      inputs: { 'segments' => [] }) # Invalid

    # Node should start as invalid
    refute node.is_valid?

    input1 = create(:video_production_node, pipeline: @pipeline)
    input2 = create(:video_production_node, pipeline: @pipeline)

    Prosopite.scan
    # Fix with valid inputs
    patch admin_video_production_pipeline_node_path(@pipeline.uuid, node.uuid),
      params: {
        node: { inputs: { 'segments' => [input1.uuid, input2.uuid] } }
      },
      headers: @headers,
      as: :json

    assert_response :success
    json = response.parsed_body

    # Node now valid
    assert json["node"]["is_valid"]
    assert_empty(json["node"]["validation_errors"])
  end

  test "PATCH update returns 404 for non-existent node" do
    patch admin_video_production_pipeline_node_path(@pipeline.uuid, 'non-existent-uuid'),
      params: { node: { title: "New Title" } },
      headers: @headers,
      as: :json

    assert_response :not_found
  end

  test "PATCH update does not allow type to be changed" do
    Prosopite.finish
    node = create(:video_production_node, pipeline: @pipeline, type: 'asset', title: "Original")

    Prosopite.scan
    patch admin_video_production_pipeline_node_path(@pipeline.uuid, node.uuid),
      params: {
        node: { title: "Updated", type: "merge-videos" }
      },
      headers: @headers,
      as: :json

    assert_response :success
    json = response.parsed_body

    # Type should not change (it's filtered out in controller)
    assert_equal "asset", json["node"]["type"]
    # But title should update
    assert_equal "Updated", json["node"]["title"]
  end

  # DESTROY tests

  test "DELETE destroy deletes node" do
    Prosopite.finish
    node = create(:video_production_node, pipeline: @pipeline)

    assert_difference 'VideoProduction::Node.count', -1 do
      Prosopite.scan
      delete admin_video_production_pipeline_node_path(@pipeline.uuid, node.uuid),
        headers: @headers,
        as: :json
    end

    assert_response :no_content
  end

  test "DELETE destroy cleans up references in other nodes" do
    Prosopite.finish
    node_to_delete = create(:video_production_node, pipeline: @pipeline, title: "To Delete")
    node_with_reference = create(:video_production_node,
      pipeline: @pipeline,
      type: "merge-videos",
      inputs: { 'segments' => [node_to_delete.uuid, 'other-uuid'] })

    Prosopite.scan
    delete admin_video_production_pipeline_node_path(@pipeline.uuid, node_to_delete.uuid),
      headers: @headers,
      as: :json

    assert_response :no_content

    # Verify reference was removed
    node_with_reference.reload
    assert_equal({ 'segments' => ['other-uuid'] }, node_with_reference.inputs)
  end

  test "DELETE destroy handles array and string references" do
    Prosopite.finish
    node_to_delete = create(:video_production_node, pipeline: @pipeline)
    node_with_array = create(:video_production_node,
      pipeline: @pipeline,
      type: "merge-videos",
      inputs: { 'segments' => [node_to_delete.uuid, 'keep-me'] })
    node_with_string = create(:video_production_node,
      pipeline: @pipeline,
      type: "generate-talking-head",
      inputs: { 'audio' => node_to_delete.uuid })

    Prosopite.scan
    delete admin_video_production_pipeline_node_path(@pipeline.uuid, node_to_delete.uuid),
      headers: @headers,
      as: :json

    assert_response :no_content

    node_with_array.reload
    node_with_string.reload

    # Array: removed from array
    assert_equal({ 'segments' => ['keep-me'] }, node_with_array.inputs)
    # String: slot removed entirely
    assert_empty(node_with_string.inputs)
  end

  test "DELETE destroy returns 404 for non-existent node" do
    delete admin_video_production_pipeline_node_path(@pipeline.uuid, 'non-existent-uuid'),
      headers: @headers,
      as: :json

    assert_response :not_found
  end

  # EXECUTE tests

  test "POST execute queues execution for ready node" do
    input1 = create(:video_production_node, :completed, pipeline: @pipeline, type: 'asset')
    input2 = create(:video_production_node, :completed, pipeline: @pipeline, type: 'asset')
    node = create(:video_production_node,
      pipeline: @pipeline,
      type: 'merge-videos',
      config: { 'provider' => 'ffmpeg' },
      inputs: { 'segments' => [input1.uuid, input2.uuid] },
      status: 'pending',
      is_valid: true)

    # Mock the defer call
    VideoProduction::Node::Executors::MergeVideos.expects(:defer).with(node)

    post execute_admin_video_production_pipeline_node_path(@pipeline.uuid, node.uuid),
      headers: @headers,
      as: :json

    assert_response :success
    json = response.parsed_body
    assert_equal node.uuid, json['node']['uuid']
    assert_equal 'merge-videos', json['node']['type']
  end

  test "POST execute queues execution for failed node (retry)" do
    input1 = create(:video_production_node, :completed, pipeline: @pipeline, type: 'asset')
    input2 = create(:video_production_node, :completed, pipeline: @pipeline, type: 'asset')
    node = create(:video_production_node,
      pipeline: @pipeline,
      type: 'merge-videos',
      status: 'failed',
      inputs: { 'segments' => [input1.uuid, input2.uuid] },
      config: { 'provider' => 'ffmpeg' },
      is_valid: true)

    # Mock the defer call
    VideoProduction::Node::Executors::MergeVideos.expects(:defer).with(node)

    post execute_admin_video_production_pipeline_node_path(@pipeline.uuid, node.uuid),
      headers: @headers,
      as: :json

    assert_response :success
    json = response.parsed_body
    assert_equal node.uuid, json['node']['uuid']
    assert_equal 'merge-videos', json['node']['type']
  end

  test "POST execute returns 422 when node is not ready (in_progress or completed)" do
    node = create(:video_production_node,
      pipeline: @pipeline,
      type: 'merge-videos',
      status: 'completed')

    post execute_admin_video_production_pipeline_node_path(@pipeline.uuid, node.uuid),
      headers: @headers,
      as: :json

    assert_response :unprocessable_entity
    json = response.parsed_body
    assert_match(/not ready to execute/i, json['error'])
    assert_match(/pending.*failed/i, json['error'])
  end

  test "POST execute returns 422 when node is not valid" do
    node = create(:video_production_node,
      pipeline: @pipeline,
      type: 'merge-videos',
      status: 'pending',
      is_valid: false,
      validation_errors: { 'inputs' => ['segments is required'] })

    post execute_admin_video_production_pipeline_node_path(@pipeline.uuid, node.uuid),
      headers: @headers,
      as: :json

    assert_response :unprocessable_entity
    json = response.parsed_body
    assert_match(/not ready to execute/i, json['error'])
    assert_match(/validation errors/i, json['error'])
  end

  test "POST execute returns 422 when inputs are not satisfied" do
    input_node = create(:video_production_node,
      pipeline: @pipeline,
      type: 'asset',
      status: 'pending')
    node = create(:video_production_node,
      pipeline: @pipeline,
      type: 'merge-videos',
      inputs: { 'segments' => [input_node.uuid] },
      status: 'pending',
      is_valid: true)

    post execute_admin_video_production_pipeline_node_path(@pipeline.uuid, node.uuid),
      headers: @headers,
      as: :json

    assert_response :unprocessable_entity
    json = response.parsed_body
    assert_match(/not ready to execute/i, json['error'])
    assert_match(/input nodes/i, json['error'])
  end

  test "POST execute returns 404 for non-existent node" do
    post execute_admin_video_production_pipeline_node_path(@pipeline.uuid, 'non-existent-uuid'),
      headers: @headers,
      as: :json

    assert_response :not_found
  end

  # OUTPUT tests

  test "GET output returns redirect to presigned URL for completed node with output" do
    node = create(:video_production_node,
      pipeline: @pipeline,
      status: 'completed',
      output: { 's3Key' => 'pipelines/test/nodes/abc/output.mp4' })

    get output_admin_video_production_pipeline_node_path(@pipeline.uuid, node.uuid),
      headers: @headers,
      as: :json

    assert_response :redirect
    assert_match %r{http://localhost:3065/jiki-videos-dev/pipelines/test/nodes/abc/output\.mp4}, response.location
    assert_match(/X-Amz-Algorithm=AWS4-HMAC-SHA256/, response.location)
    assert_match(/X-Amz-Signature=/, response.location)
  end

  test "GET output returns redirect to presigned URL for asset node" do
    node = create(:video_production_node,
      pipeline: @pipeline,
      type: 'asset',
      asset: { 'source' => 'test-assets/video1.mp4', 'type' => 'video' })

    get output_admin_video_production_pipeline_node_path(@pipeline.uuid, node.uuid),
      headers: @headers,
      as: :json

    assert_response :redirect
    assert_match %r{http://localhost:3065/jiki-videos-dev/test-assets/video1\.mp4}, response.location
    assert_match(/X-Amz-Algorithm=AWS4-HMAC-SHA256/, response.location)
  end

  test "GET output returns 422 when node has no output" do
    node = create(:video_production_node,
      pipeline: @pipeline,
      type: 'merge-videos',
      status: 'pending')

    get output_admin_video_production_pipeline_node_path(@pipeline.uuid, node.uuid),
      headers: @headers,
      as: :json

    assert_response :unprocessable_entity
    json = response.parsed_body
    assert_match(/no output/i, json['error'])
  end

  test "GET output returns 404 for non-existent pipeline" do
    get output_admin_video_production_pipeline_node_path('non-existent-uuid', 'node-uuid'),
      headers: @headers,
      as: :json

    assert_response :not_found
  end

  test "GET output returns 404 for non-existent node" do
    get output_admin_video_production_pipeline_node_path(@pipeline.uuid, 'non-existent-uuid'),
      headers: @headers,
      as: :json

    assert_response :not_found
  end

  test "GET output returns 404 when node belongs to different pipeline" do
    other_pipeline = create(:video_production_pipeline)
    node = create(:video_production_node,
      pipeline: other_pipeline,
      status: 'completed',
      output: { 's3Key' => 'test.mp4' })

    get output_admin_video_production_pipeline_node_path(@pipeline.uuid, node.uuid),
      headers: @headers,
      as: :json

    assert_response :not_found
  end
end
