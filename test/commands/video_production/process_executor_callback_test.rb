require 'test_helper'

class VideoProduction::ProcessExecutorCallbackTest < ActiveSupport::TestCase
  test "processes successful callback for merge-videos" do
    pipeline = create(:video_production_pipeline)
    node = create(:video_production_node, :merge_videos, pipeline: pipeline, status: 'in_progress')
    node.update!(metadata: { 'process_uuid' => 'test-uuid', 'started_at' => Time.current.iso8601 })

    VideoProduction::ProcessExecutorCallback.(
      node,
      'merge-videos',
      result: { 's3_key' => 'test.mp4', 'duration' => 10, 'size' => 1024 }
    )

    node.reload
    assert_equal 'completed', node.status
    assert_equal 'test.mp4', node.output['s3Key']
    assert_equal 10, node.output['duration']
    assert_equal 1024, node.output['size']
  end

  test "processes error callback" do
    pipeline = create(:video_production_pipeline)
    node = create(:video_production_node, :merge_videos, pipeline: pipeline, status: 'in_progress')
    node.update!(metadata: { 'process_uuid' => 'test-uuid', 'started_at' => Time.current.iso8601 })

    VideoProduction::ProcessExecutorCallback.(
      node,
      'merge-videos',
      error: 'FFmpeg failed',
      error_type: 'ffmpeg_error'
    )

    node.reload
    assert_equal 'failed', node.status
    assert_includes node.metadata['error'], 'FFmpeg failed'
  end

  test "raises error for stale callback (completed node)" do
    pipeline = create(:video_production_pipeline)
    node = create(:video_production_node, :merge_videos, pipeline: pipeline, status: 'completed')

    assert_raises(VideoProduction::ProcessExecutorCallback::StaleCallbackError) do
      VideoProduction::ProcessExecutorCallback.(
        node,
        'merge-videos',
        result: { 's3_key' => 'test.mp4' }
      )
    end
  end

  test "raises error for stale callback (failed node)" do
    pipeline = create(:video_production_pipeline)
    node = create(:video_production_node, :merge_videos, pipeline: pipeline, status: 'failed')

    assert_raises(VideoProduction::ProcessExecutorCallback::StaleCallbackError) do
      VideoProduction::ProcessExecutorCallback.(
        node,
        'merge-videos',
        result: { 's3_key' => 'test.mp4' }
      )
    end
  end

  test "handles symbolized keys in result" do
    pipeline = create(:video_production_pipeline)
    node = create(:video_production_node, :merge_videos, pipeline: pipeline, status: 'in_progress')
    node.update!(metadata: { 'process_uuid' => 'test-uuid', 'started_at' => Time.current.iso8601 })

    VideoProduction::ProcessExecutorCallback.(
      node,
      'merge-videos',
      result: { s3_key: 'test.mp4', duration: 10, size: 1024 } # Symbolized keys
    )

    node.reload
    assert_equal 'completed', node.status
    assert_equal 'test.mp4', node.output['s3Key']
  end

  test "accepts callback with matching process_uuid" do
    pipeline = create(:video_production_pipeline)
    node = create(:video_production_node, :merge_videos, pipeline: pipeline, status: 'in_progress')
    node.update!(metadata: { 'process_uuid' => 'test-uuid-123', 'started_at' => Time.current.iso8601 })

    VideoProduction::ProcessExecutorCallback.(
      node,
      'merge-videos',
      process_uuid: 'test-uuid-123',
      result: { 's3_key' => 'test.mp4', 'duration' => 10, 'size' => 1024 }
    )

    node.reload
    assert_equal 'completed', node.status
  end

  test "rejects callback with mismatched process_uuid" do
    pipeline = create(:video_production_pipeline)
    node = create(:video_production_node, :merge_videos, pipeline: pipeline, status: 'in_progress')
    node.update!(metadata: { 'process_uuid' => 'current-uuid', 'started_at' => Time.current.iso8601 })

    assert_raises(VideoProduction::ProcessExecutorCallback::StaleCallbackError) do
      VideoProduction::ProcessExecutorCallback.(
        node,
        'merge-videos',
        process_uuid: 'old-uuid', # Mismatched process_uuid
        result: { 's3_key' => 'test.mp4' }
      )
    end

    node.reload
    # Node should remain in_progress since callback was rejected
    assert_equal 'in_progress', node.status
  end

  test "accepts callback without process_uuid for backward compatibility" do
    pipeline = create(:video_production_pipeline)
    node = create(:video_production_node, :merge_videos, pipeline: pipeline, status: 'in_progress')
    node.update!(metadata: { 'process_uuid' => 'test-uuid', 'started_at' => Time.current.iso8601 })

    VideoProduction::ProcessExecutorCallback.(
      node,
      'merge-videos',
      # No process_uuid provided
      result: { 's3_key' => 'test.mp4', 'duration' => 10, 'size' => 1024 }
    )

    node.reload
    assert_equal 'completed', node.status
  end
end
