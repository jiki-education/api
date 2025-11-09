require "test_helper"

class VideoProduction::APIs::ElevenLabs::CheckForResultTest < ActiveSupport::TestCase
  test "processes completed result" do
    pipeline = create(:video_production_pipeline)
    node = create(:video_production_node,
      pipeline:,
      status: 'in_progress',
      metadata: { 'process_uuid' => 'test-uuid', 'audio_id' => 'audio-123' })

    # Stub ElevenLabs API to return completed
    stub_request(:get, "https://api.elevenlabs.io/v1/text-to-speech/status/audio-123").
      with(headers: { 'xi-api-key' => Jiki.secrets.elevenlabs_api_key }).
      to_return(
        status: 200,
        headers: { 'Content-Type' => 'application/json' },
        body: { status: 'completed', audio_url: 'https://elevenlabs.io/audio/123.mp3' }.to_json
      )

    # Mock ProcessResult
    VideoProduction::APIs::ElevenLabs::ProcessResult.expects(:call).with(
      node.uuid,
      'test-uuid',
      'https://elevenlabs.io/audio/123.mp3'
    )

    VideoProduction::APIs::ElevenLabs::CheckForResult.(node, 'test-uuid', 'audio-123', 1)
  end

  test "reschedules when status is processing" do
    pipeline = create(:video_production_pipeline)
    node = create(:video_production_node,
      pipeline:,
      status: 'in_progress',
      metadata: { 'process_uuid' => 'test-uuid', 'audio_id' => 'audio-123' })

    # Stub ElevenLabs API to return processing
    stub_request(:get, "https://api.elevenlabs.io/v1/text-to-speech/status/audio-123").
      with(headers: { 'xi-api-key' => Jiki.secrets.elevenlabs_api_key }).
      to_return(
        status: 200,
        headers: { 'Content-Type' => 'application/json' },
        body: { status: 'processing' }.to_json
      )

    # Verify job gets rescheduled with incremented attempt
    assert_enqueued_with(
      job: MandateJob,
      args: ["VideoProduction::APIs::ElevenLabs::CheckForResult", node, 'test-uuid', 'audio-123', 2]
    ) do
      VideoProduction::APIs::ElevenLabs::CheckForResult.(node, 'test-uuid', 'audio-123', 1)
    end

    # Node should still be in_progress
    assert_equal 'in_progress', node.reload.status
  end

  test "marks execution as failed when status is failed" do
    pipeline = create(:video_production_pipeline)
    node = create(:video_production_node,
      pipeline:,
      status: 'in_progress',
      metadata: { 'process_uuid' => 'test-uuid' })

    # Stub ElevenLabs API to return failed
    stub_request(:get, "https://api.elevenlabs.io/v1/text-to-speech/status/audio-123").
      with(headers: { 'xi-api-key' => Jiki.secrets.elevenlabs_api_key }).
      to_return(
        status: 200,
        headers: { 'Content-Type' => 'application/json' },
        body: { status: 'failed', error: 'API error occurred' }.to_json
      )

    VideoProduction::Node::ExecutionFailed.expects(:call).with(node, "API generation failed: API error occurred", 'test-uuid')

    VideoProduction::APIs::ElevenLabs::CheckForResult.(node, 'test-uuid', 'audio-123', 1)
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

    VideoProduction::APIs::ElevenLabs::CheckForResult.(node, 'test-uuid', 'audio-123', 61)
  end

  test "marks execution as failed when polling raises error" do
    pipeline = create(:video_production_pipeline)
    node = create(:video_production_node,
      pipeline:,
      status: 'in_progress',
      metadata: { 'process_uuid' => 'test-uuid' })

    # Stub ElevenLabs API to raise error
    stub_request(:get, "https://api.elevenlabs.io/v1/text-to-speech/status/audio-123").
      with(headers: { 'xi-api-key' => Jiki.secrets.elevenlabs_api_key }).
      to_timeout

    VideoProduction::Node::ExecutionFailed.expects(:call).with { |n, msg, uuid| n == node && msg.include?('Polling error') && uuid == 'test-uuid' }

    assert_raises(StandardError) do
      VideoProduction::APIs::ElevenLabs::CheckForResult.(node, 'test-uuid', 'audio-123', 1)
    end
  end

  # Race Condition Tests
  test "does not process result when node already completed (webhook beat polling)" do
    pipeline = create(:video_production_pipeline)
    node = create(:video_production_node,
      pipeline:,
      status: 'in_progress',
      metadata: { 'process_uuid' => 'test-uuid', 'audio_id' => 'audio-123' })

    # Stub ElevenLabs API to return completed
    stub_request(:get, "https://api.elevenlabs.io/v1/text-to-speech/status/audio-123").
      with(headers: { 'xi-api-key' => Jiki.secrets.elevenlabs_api_key }).
      to_return(
        status: 200,
        headers: { 'Content-Type' => 'application/json' },
        body: { status: 'completed', audio_url: 'https://elevenlabs.io/audio/123.mp3' }.to_json
      )

    # Simulate webhook already processed and marked node as completed
    node.update!(status: 'completed', output: { 's3Key' => 'from-webhook.mp3' })

    # ProcessResult should NOT be called because node is already completed
    VideoProduction::APIs::ElevenLabs::ProcessResult.expects(:call).never

    # The polling job should exit silently
    VideoProduction::APIs::ElevenLabs::CheckForResult.(node, 'test-uuid', 'audio-123', 1)

    # Node output should still be from webhook (not overwritten)
    assert_equal 'from-webhook.mp3', node.reload.output['s3Key']
  end

  test "does not process result when node failed during polling" do
    pipeline = create(:video_production_pipeline)
    node = create(:video_production_node,
      pipeline:,
      status: 'in_progress',
      metadata: { 'process_uuid' => 'test-uuid', 'audio_id' => 'audio-123' })

    # Stub ElevenLabs API to return completed
    stub_request(:get, "https://api.elevenlabs.io/v1/text-to-speech/status/audio-123").
      with(headers: { 'xi-api-key' => Jiki.secrets.elevenlabs_api_key }).
      to_return(
        status: 200,
        headers: { 'Content-Type' => 'application/json' },
        body: { status: 'completed', audio_url: 'https://elevenlabs.io/audio/123.mp3' }.to_json
      )

    # Simulate node failed for some other reason (timeout, manual intervention, etc)
    node.update!(status: 'failed', metadata: { error: 'Manual cancellation' })

    # ProcessResult should NOT be called because node is no longer in_progress
    VideoProduction::APIs::ElevenLabs::ProcessResult.expects(:call).never

    # The polling job should exit silently
    VideoProduction::APIs::ElevenLabs::CheckForResult.(node, 'test-uuid', 'audio-123', 1)

    # Node should still be failed (not overwritten to completed)
    assert_equal 'failed', node.reload.status
  end

  test "does not process result when second execution started (first polling job is stale)" do
    pipeline = create(:video_production_pipeline)
    node = create(:video_production_node,
      pipeline:,
      status: 'in_progress',
      metadata: { 'process_uuid' => 'first-uuid', 'audio_id' => 'audio-123' })

    # Start first execution with audio-123
    # ... polling job is scheduled ...

    # User triggers second execution before first completes
    # This would normally call ExecutionStarted again, changing the node
    node.update!(
      status: 'in_progress',
      metadata: { 'process_uuid' => 'second-uuid', 'audio_id' => 'audio-456' } # New execution with different process_uuid
    )

    # Stub ElevenLabs API for the FIRST execution (audio-123)
    stub_request(:get, "https://api.elevenlabs.io/v1/text-to-speech/status/audio-123").
      with(headers: { 'xi-api-key' => Jiki.secrets.elevenlabs_api_key }).
      to_return(
        status: 200,
        headers: { 'Content-Type' => 'application/json' },
        body: { status: 'completed', audio_url: 'https://elevenlabs.io/audio/123.mp3' }.to_json
      )

    # The first (stale) polling job should NOT process its result
    # because a second execution has started (process_uuid doesn't match)
    VideoProduction::APIs::ElevenLabs::ProcessResult.expects(:call).never

    # First polling job runs with old UUID (should detect it's stale and exit)
    VideoProduction::APIs::ElevenLabs::CheckForResult.(node, 'first-uuid', 'audio-123', 1)

    # Node should still be waiting for second execution (audio-456)
    assert_equal 'in_progress', node.reload.status
    assert_equal 'second-uuid', node.reload.metadata['process_uuid']
    assert_equal 'audio-456', node.reload.metadata['audio_id']
  end
end
