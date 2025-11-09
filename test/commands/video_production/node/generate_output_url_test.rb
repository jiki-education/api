require "test_helper"

class VideoProduction::Node::GenerateOutputUrlTest < ActiveSupport::TestCase
  test "generates presigned URL for completed node with output" do
    pipeline = create(:video_production_pipeline)
    node = create(:video_production_node,
      pipeline: pipeline,
      status: 'completed',
      output: { 's3Key' => 'pipelines/test/nodes/abc/output.mp4' })

    presigned_url = VideoProduction::Node::GenerateOutputUrl.(node)

    assert presigned_url.present?
    assert_match %r{http://localhost:3065/jiki-videos-dev/pipelines/test/nodes/abc/output\.mp4}, presigned_url
    assert_match(/X-Amz-Algorithm=AWS4-HMAC-SHA256/, presigned_url)
    assert_match(/X-Amz-Signature=/, presigned_url)
    assert_match(/X-Amz-Expires=3600/, presigned_url) # 1 hour expiry
  end

  test "generates presigned URL for asset node with source" do
    pipeline = create(:video_production_pipeline)
    node = create(:video_production_node,
      pipeline: pipeline,
      type: 'asset',
      asset: { 'source' => 'test-assets/video1.mp4', 'type' => 'video' })

    presigned_url = VideoProduction::Node::GenerateOutputUrl.(node)

    assert presigned_url.present?
    assert_match %r{http://localhost:3065/jiki-videos-dev/test-assets/video1\.mp4}, presigned_url
    assert_match(/X-Amz-Algorithm=AWS4-HMAC-SHA256/, presigned_url)
  end

  test "raises error when node has no output" do
    pipeline = create(:video_production_pipeline)
    node = create(:video_production_node,
      pipeline: pipeline,
      type: 'merge-videos',
      status: 'pending')

    error = assert_raises(VideoProduction::Node::GenerateOutputUrl::NoOutputError) do
      VideoProduction::Node::GenerateOutputUrl.(node)
    end

    assert_match(/no output/i, error.message)
  end

  test "raises error when asset node has no source" do
    pipeline = create(:video_production_pipeline)
    node = create(:video_production_node,
      pipeline: pipeline,
      type: 'asset',
      asset: { 'type' => 'video' }) # Missing 'source'

    error = assert_raises(VideoProduction::Node::GenerateOutputUrl::NoOutputError) do
      VideoProduction::Node::GenerateOutputUrl.(node)
    end

    assert_match(/no output/i, error.message)
  end

  test "prefers output s3_key over asset source for asset nodes with both" do
    pipeline = create(:video_production_pipeline)
    node = create(:video_production_node,
      pipeline: pipeline,
      type: 'asset',
      asset: { 'source' => 'test-assets/original.mp4', 'type' => 'video' },
      output: { 's3Key' => 'processed/final.mp4' })

    presigned_url = VideoProduction::Node::GenerateOutputUrl.(node)

    # Should use the output s3_key, not the asset source
    assert_match %r{processed/final\.mp4}, presigned_url
    refute_match %r{test-assets/original\.mp4}, presigned_url
  end
end
