require "test_helper"

class VideoProduction::Node::Executors::MergeVideosTest < ActiveSupport::TestCase
  test "successfully invokes Lambda asynchronously" do
    pipeline = create(:video_production_pipeline)

    # Create input nodes with outputs
    input1 = create(:video_production_node,
      pipeline:,
      output: { 's3Key' => 'path/to/video1.mp4', 'type' => 'video' })
    input2 = create(:video_production_node,
      pipeline:,
      output: { 's3Key' => 'path/to/video2.mp4', 'type' => 'video' })

    node = create(:video_production_node,
      pipeline:,
      type: 'merge-videos',
      config: { 'provider' => 'ffmpeg' },
      inputs: { 'segments' => [input1.uuid, input2.uuid] },
      status: 'pending')

    # Mock async Lambda invocation (returns immediately, no result)
    bucket = Jiki.config.s3_bucket_video_production
    VideoProduction::InvokeLambda.expects(:call).with do |function_name, payload|
      function_name == "jiki-video-merger-test" &&
        payload[:input_videos] == [
          "s3://#{bucket}/path/to/video1.mp4",
          "s3://#{bucket}/path/to/video2.mp4"
        ] &&
        payload[:output_bucket] == bucket &&
        payload[:output_key] == "pipelines/#{pipeline.uuid}/nodes/#{node.uuid}/output.mp4" &&
        payload[:callback_url] == "#{Jiki.config.spi_base_url}/video_production/executor_callback" &&
        payload[:node_uuid] == node.uuid &&
        payload[:executor_type] == 'merge-videos' &&
        payload[:process_uuid].present? # Verify process_uuid is included
    end.returns({ status: 'invoked' })

    VideoProduction::Node::Executors::MergeVideos.(node)

    node.reload
    # After async invocation, node should be in_progress (not completed)
    assert_equal 'in_progress', node.status
    refute_nil node.metadata['started_at']
    refute_nil node.metadata['process_uuid']
    # Output will be set via callback, not here
    assert_nil node.output
  end

  test "raises error when no segments specified" do
    pipeline = create(:video_production_pipeline)
    node = create(:video_production_node,
      pipeline:,
      type: 'merge-videos',
      config: { 'provider' => 'ffmpeg' },
      inputs: { 'segments' => [] },
      status: 'pending')

    error = assert_raises(RuntimeError) do
      VideoProduction::Node::Executors::MergeVideos.(node)
    end

    assert_equal "No segments specified", error.message
    node.reload
    assert_equal 'failed', node.status
  end

  test "raises error when fewer than 2 segments" do
    pipeline = create(:video_production_pipeline)
    input1 = create(:video_production_node, pipeline:)

    node = create(:video_production_node,
      pipeline:,
      type: 'merge-videos',
      config: { 'provider' => 'ffmpeg' },
      inputs: { 'segments' => [input1.uuid] },
      status: 'pending')

    error = assert_raises(RuntimeError) do
      VideoProduction::Node::Executors::MergeVideos.(node)
    end

    assert_equal "At least 2 segments required", error.message
    node.reload
    assert_equal 'failed', node.status
  end

  test "raises error when input node has no output" do
    pipeline = create(:video_production_pipeline)
    input1 = create(:video_production_node, pipeline:, output: nil)
    input2 = create(:video_production_node, pipeline:, output: nil)

    node = create(:video_production_node,
      pipeline:,
      type: 'merge-videos',
      config: { 'provider' => 'ffmpeg' },
      inputs: { 'segments' => [input1.uuid, input2.uuid] },
      status: 'pending')

    error = assert_raises(RuntimeError) do
      VideoProduction::Node::Executors::MergeVideos.(node)
    end

    assert_match(/has no output/, error.message)
    node.reload
    assert_equal 'failed', node.status
  end

  test "preserves input order from segments array" do
    pipeline = create(:video_production_pipeline)

    input1 = create(:video_production_node,
      pipeline:,
      output: { 's3Key' => 'path/to/video1.mp4' })
    input2 = create(:video_production_node,
      pipeline:,
      output: { 's3Key' => 'path/to/video2.mp4' })
    input3 = create(:video_production_node,
      pipeline:,
      output: { 's3Key' => 'path/to/video3.mp4' })

    # Intentionally put them in a different order
    node = create(:video_production_node,
      pipeline:,
      type: 'merge-videos',
      config: { 'provider' => 'ffmpeg' },
      inputs: { 'segments' => [input3.uuid, input1.uuid, input2.uuid] },
      status: 'pending')

    bucket = Jiki.config.s3_bucket_video_production
    VideoProduction::InvokeLambda.expects(:call).with do |_function_name, payload|
      # Verify order matches the segments array
      payload[:input_videos] == [
        "s3://#{bucket}/path/to/video3.mp4",
        "s3://#{bucket}/path/to/video1.mp4",
        "s3://#{bucket}/path/to/video2.mp4"
      ]
    end.returns({ status: 'invoked' })

    VideoProduction::Node::Executors::MergeVideos.(node)
  end

  test "uses correct Lambda function name from environment" do
    pipeline = create(:video_production_pipeline)
    input1 = create(:video_production_node,
      pipeline:,
      output: { 's3Key' => 'video1.mp4' })
    input2 = create(:video_production_node,
      pipeline:,
      output: { 's3Key' => 'video2.mp4' })

    node = create(:video_production_node,
      pipeline:,
      type: 'merge-videos',
      config: { 'provider' => 'ffmpeg' },
      inputs: { 'segments' => [input1.uuid, input2.uuid] },
      status: 'pending')

    ENV.stubs(:fetch).with('RAILS_ENV', 'development').returns('test')
    ENV.stubs(:fetch).with('VIDEO_MERGER_LAMBDA_NAME', 'jiki-video-merger-test').returns('custom-lambda-name')

    VideoProduction::InvokeLambda.expects(:call).with(
      'custom-lambda-name',
      anything
    ).returns({ status: 'invoked' })

    VideoProduction::Node::Executors::MergeVideos.(node)
  end

  test "marks execution as started before processing" do
    pipeline = create(:video_production_pipeline)
    input1 = create(:video_production_node,
      pipeline:,
      output: { 's3Key' => 'video1.mp4' })
    input2 = create(:video_production_node,
      pipeline:,
      output: { 's3Key' => 'video2.mp4' })

    node = create(:video_production_node,
      pipeline:,
      type: 'merge-videos',
      config: { 'provider' => 'ffmpeg' },
      inputs: { 'segments' => [input1.uuid, input2.uuid] },
      status: 'pending')

    VideoProduction::InvokeLambda.stubs(:call).returns({ status: 'invoked' })

    VideoProduction::Node::Executors::MergeVideos.(node)

    node.reload
    refute_nil node.metadata['started_at']
    refute_nil node.metadata['process_uuid']
  end
end
