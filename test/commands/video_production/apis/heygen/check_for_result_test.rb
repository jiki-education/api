require "test_helper"

class VideoProduction::APIs::Heygen::CheckForResultTest < ActiveSupport::TestCase
  test "processes completed result" do
    pipeline = create(:video_production_pipeline)
    node = create(:video_production_node,
      pipeline:,
      status: 'in_progress',
      metadata: { 'process_uuid' => 'test-uuid', 'video_id' => 'video-123' })

    # Stub HeyGen API to return completed
    stub_request(:get, "https://api.heygen.com/v1/video_status.get?video_id=video-123").
      with(headers: { 'X-Api-Key' => Jiki.secrets.heygen_api_key }).
      to_return(
        status: 200,
        headers: { 'Content-Type' => 'application/json' },
        body: {
          data: {
            status: 'completed',
            video_url: 'https://heygen.com/video/123.mp4',
            thumbnail_url: 'https://heygen.com/thumb/123.jpg'
          }
        }.to_json
      )

    # Mock ProcessResult
    VideoProduction::APIs::Heygen::ProcessResult.expects(:call).with(
      node.uuid,
      'test-uuid',
      'https://heygen.com/video/123.mp4'
    )

    VideoProduction::APIs::Heygen::CheckForResult.(node, 'test-uuid', 'video-123', 1)
  end

  test "reschedules when status is processing" do
    pipeline = create(:video_production_pipeline)
    node = create(:video_production_node,
      pipeline:,
      status: 'in_progress',
      metadata: { 'process_uuid' => 'test-uuid', 'video_id' => 'video-123' })

    # Stub HeyGen API to return processing
    stub_request(:get, "https://api.heygen.com/v1/video_status.get?video_id=video-123").
      to_return(
        status: 200,
        headers: { 'Content-Type' => 'application/json' },
        body: { data: { status: 'processing' } }.to_json
      )

    # Verify job gets rescheduled with incremented attempt
    assert_enqueued_with(
      job: MandateJob,
      args: ["VideoProduction::APIs::Heygen::CheckForResult", node, 'test-uuid', 'video-123', 2]
    ) do
      VideoProduction::APIs::Heygen::CheckForResult.(node, 'test-uuid', 'video-123', 1)
    end

    # Node should still be in_progress
    assert_equal 'in_progress', node.reload.status
  end

  test "reschedules when status is pending" do
    pipeline = create(:video_production_pipeline)
    node = create(:video_production_node,
      pipeline:,
      status: 'in_progress',
      metadata: { 'process_uuid' => 'test-uuid', 'video_id' => 'video-123' })

    # Stub HeyGen API to return pending
    stub_request(:get, "https://api.heygen.com/v1/video_status.get?video_id=video-123").
      to_return(
        status: 200,
        headers: { 'Content-Type' => 'application/json' },
        body: { data: { status: 'pending' } }.to_json
      )

    # Verify job gets rescheduled
    assert_enqueued_with(
      job: MandateJob,
      args: ["VideoProduction::APIs::Heygen::CheckForResult", node, 'test-uuid', 'video-123', 2]
    ) do
      VideoProduction::APIs::Heygen::CheckForResult.(node, 'test-uuid', 'video-123', 1)
    end
  end

  test "marks execution as failed when status is failed" do
    pipeline = create(:video_production_pipeline)
    node = create(:video_production_node,
      pipeline:,
      status: 'in_progress',
      metadata: { 'process_uuid' => 'test-uuid' })

    # Stub HeyGen API to return failed
    stub_request(:get, "https://api.heygen.com/v1/video_status.get?video_id=video-123").
      to_return(
        status: 200,
        headers: { 'Content-Type' => 'application/json' },
        body: { data: { status: 'failed', error: 'Video generation failed' } }.to_json
      )

    VideoProduction::Node::ExecutionFailed.expects(:call).with(
      node,
      "API generation failed: Video generation failed",
      'test-uuid'
    )

    VideoProduction::APIs::Heygen::CheckForResult.(node, 'test-uuid', 'video-123', 1)
  end

  test "marks execution as failed when max attempts exceeded" do
    pipeline = create(:video_production_pipeline)
    node = create(:video_production_node,
      pipeline:,
      status: 'in_progress',
      metadata: { 'process_uuid' => 'test-uuid' })

    VideoProduction::Node::ExecutionFailed.expects(:call).with(
      node,
      "Polling timeout after 60 attempts",
      'test-uuid'
    )

    VideoProduction::APIs::Heygen::CheckForResult.(node, 'test-uuid', 'video-123', 61)
  end

  test "marks execution as failed when polling raises error" do
    pipeline = create(:video_production_pipeline)
    node = create(:video_production_node,
      pipeline:,
      status: 'in_progress',
      metadata: { 'process_uuid' => 'test-uuid' })

    # Stub HeyGen API to raise error
    stub_request(:get, "https://api.heygen.com/v1/video_status.get?video_id=video-123").
      to_timeout

    VideoProduction::Node::ExecutionFailed.expects(:call).with do |n, msg, uuid|
      n == node && msg.include?('Polling error') && uuid == 'test-uuid'
    end

    assert_raises(StandardError) do
      VideoProduction::APIs::Heygen::CheckForResult.(node, 'test-uuid', 'video-123', 1)
    end
  end

  test "handles rate limiting gracefully" do
    pipeline = create(:video_production_pipeline)
    node = create(:video_production_node,
      pipeline:,
      status: 'in_progress',
      metadata: { 'process_uuid' => 'test-uuid' })

    # Stub HeyGen API to return 429 rate limit
    stub_request(:get, "https://api.heygen.com/v1/video_status.get?video_id=video-123").
      to_return(status: 429)

    # Should reschedule as if status is still processing
    assert_enqueued_with(
      job: MandateJob,
      args: ["VideoProduction::APIs::Heygen::CheckForResult", node, 'test-uuid', 'video-123', 2]
    ) do
      VideoProduction::APIs::Heygen::CheckForResult.(node, 'test-uuid', 'video-123', 1)
    end
  end

  # Race Condition Tests
  test "does not process result when node already completed" do
    pipeline = create(:video_production_pipeline)
    node = create(:video_production_node,
      pipeline:,
      status: 'completed',
      output: { 's3Key' => 'from-webhook.mp4' },
      metadata: { 'process_uuid' => 'test-uuid' })

    stub_request(:get, "https://api.heygen.com/v1/video_status.get?video_id=video-123").
      to_return(
        status: 200,
        body: { data: { status: 'completed', video_url: 'https://heygen.com/video/123.mp4' } }.to_json
      )

    # ProcessResult should NOT be called
    VideoProduction::APIs::Heygen::ProcessResult.expects(:call).never

    VideoProduction::APIs::Heygen::CheckForResult.(node, 'test-uuid', 'video-123', 1)

    # Output should remain unchanged
    assert_equal 'from-webhook.mp4', node.reload.output['s3Key']
  end

  test "does not process result when process_uuid changed" do
    pipeline = create(:video_production_pipeline)
    node = create(:video_production_node,
      pipeline:,
      status: 'in_progress',
      metadata: { 'process_uuid' => 'second-uuid', 'video_id' => 'video-456' })

    stub_request(:get, "https://api.heygen.com/v1/video_status.get?video_id=video-123").
      to_return(
        status: 200,
        body: { data: { status: 'completed', video_url: 'https://heygen.com/video/123.mp4' } }.to_json
      )

    # ProcessResult should NOT be called (stale polling job)
    VideoProduction::APIs::Heygen::ProcessResult.expects(:call).never

    # First polling job with old UUID should exit silently
    VideoProduction::APIs::Heygen::CheckForResult.(node, 'first-uuid', 'video-123', 1)

    # Node should still be waiting for second execution
    assert_equal 'in_progress', node.reload.status
    assert_equal 'second-uuid', node.reload.metadata['process_uuid']
  end
end
