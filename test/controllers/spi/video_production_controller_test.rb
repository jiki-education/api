require "test_helper"

class SPI::VideoProductionControllerTest < ActionDispatch::IntegrationTest
  test "executor_callback processes successful result" do
    pipeline = create(:video_production_pipeline)
    node = create(:video_production_node, :merge_videos, pipeline: pipeline, status: 'in_progress')
    node.update!(metadata: { 'process_uuid' => 'test-uuid', 'started_at' => Time.current.iso8601 })

    post spi_video_production_executor_callback_path, params: {
      node_uuid: node.uuid,
      executor_type: 'merge-videos',
      result: {
        s3_key: 'pipelines/123/nodes/456/output.mp4',
        duration: 10,
        size: 1024
      }
    }, as: :json

    assert_response :ok
    assert_json_response({
      status: 'ok'
    })

    node.reload
    assert_equal 'completed', node.status
    assert_equal 'pipelines/123/nodes/456/output.mp4', node.output['s3Key']
    assert_equal 10, node.output['duration']
    assert_equal 1024, node.output['size']
  end

  test "executor_callback processes error result" do
    pipeline = create(:video_production_pipeline)
    node = create(:video_production_node, :merge_videos, pipeline: pipeline, status: 'in_progress')
    node.update!(metadata: { 'process_uuid' => 'test-uuid', 'started_at' => Time.current.iso8601 })

    post spi_video_production_executor_callback_path, params: {
      node_uuid: node.uuid,
      executor_type: 'merge-videos',
      error: 'FFmpeg failed',
      error_type: 'ffmpeg_error'
    }, as: :json

    assert_response :ok

    node.reload
    assert_equal 'failed', node.status
    assert_includes node.metadata['error'], 'FFmpeg failed'
  end

  test "executor_callback returns 404 for non-existent node" do
    post spi_video_production_executor_callback_path, params: {
      node_uuid: 'non-existent-uuid',
      executor_type: 'merge-videos',
      result: { s3_key: 'test.mp4', duration: 10, size: 1024 }
    }, as: :json

    assert_response :not_found
  end

  test "executor_callback ignores stale callbacks" do
    pipeline = create(:video_production_pipeline)
    node = create(:video_production_node, :merge_videos, pipeline: pipeline, status: 'completed')

    post spi_video_production_executor_callback_path, params: {
      node_uuid: node.uuid,
      executor_type: 'merge-videos',
      result: { s3_key: 'test.mp4', duration: 10, size: 1024 }
    }, as: :json

    assert_response :ok
    assert_json_response({
      status: 'ignored',
      reason: 'stale_callback'
    })
  end

  test "executor_callback requires node_uuid" do
    post spi_video_production_executor_callback_path, params: {
      executor_type: 'merge-videos',
      result: { s3_key: 'test.mp4' }
    }, as: :json

    assert_response :bad_request

    json = response.parsed_body
    assert_includes json['error'], 'node_uuid'
  end

  test "executor_callback requires executor_type" do
    post spi_video_production_executor_callback_path, params: {
      node_uuid: 'some-uuid',
      result: { s3_key: 'test.mp4' }
    }, as: :json

    assert_response :bad_request

    json = response.parsed_body
    assert_includes json['error'], 'executor_type'
  end
end
