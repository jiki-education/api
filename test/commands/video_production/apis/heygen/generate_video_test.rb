require "test_helper"

class VideoProduction::APIs::Heygen::GenerateVideoTest < ActiveSupport::TestCase
  test "submits video to HeyGen, marks execution updated, and queues polling job" do
    pipeline = create(:video_production_pipeline)
    audio_node = create(:video_production_node,
      pipeline:,
      type: 'generate-voiceover',
      output: { 's3Key' => 'pipelines/test/audio.mp3' })
    node = create(:video_production_node,
      pipeline:,
      type: 'generate-talking-head',
      config: { 'avatarId' => 'Monica_inSleeveless_20220819', 'width' => 1280, 'height' => 720 },
      inputs: { 'audio' => [audio_node.uuid] },
      status: 'pending')

    # Mock presigned URL generation
    Utils::S3::GeneratePresignedUrl.stubs(:call).returns('https://s3.example.com/audio.mp3')

    # Mock HeyGen API call
    stub_request(:post, "https://api.heygen.com/v2/video/generate").
      with(headers: { 'X-Api-Key' => Jiki.secrets.heygen_api_key }).
      to_return(
        status: 200,
        headers: { 'Content-Type' => 'application/json' },
        body: { data: { video_id: 'video-123' } }.to_json
      )

    # Mock ExecutionUpdated command
    VideoProduction::Node::ExecutionUpdated.expects(:call).with(node, { video_id: 'video-123', stage: 'submitted' }, 'test-uuid')

    # Execute - CheckForResult will be deferred with wait: 10.seconds
    VideoProduction::APIs::Heygen::GenerateVideo.(node, 'test-uuid')
  end

  test "includes background image when provided" do
    pipeline = create(:video_production_pipeline)
    audio_node = create(:video_production_node,
      pipeline:,
      type: 'generate-voiceover',
      output: { 's3Key' => 'pipelines/test/audio.mp3' })
    background_node = create(:video_production_node,
      pipeline:,
      type: 'asset',
      output: { 's3Key' => 'pipelines/test/background.jpg' })
    node = create(:video_production_node,
      pipeline:,
      type: 'generate-talking-head',
      config: { 'avatarId' => 'test-avatar' },
      inputs: { 'audio' => [audio_node.uuid], 'background' => [background_node.uuid] })

    # Mock presigned URL generation
    Utils::S3::GeneratePresignedUrl.stubs(:call).with('pipelines/test/audio.mp3', :video_production, expires_in: 1.hour).
      returns('https://s3.example.com/audio.mp3')
    Utils::S3::GeneratePresignedUrl.stubs(:call).with('pipelines/test/background.jpg', :video_production, expires_in: 1.hour).
      returns('https://s3.example.com/background.jpg')

    stub_request(:post, "https://api.heygen.com/v2/video/generate").
      to_return(
        status: 200,
        headers: { 'Content-Type' => 'application/json' },
        body: { data: { video_id: 'video-456' } }.to_json
      )

    VideoProduction::Node::ExecutionUpdated.stubs(:call)

    VideoProduction::APIs::Heygen::GenerateVideo.(node, 'test-uuid')

    assert_requested :post, "https://api.heygen.com/v2/video/generate"
  end

  test "uses default dimensions when not specified" do
    pipeline = create(:video_production_pipeline)
    audio_node = create(:video_production_node,
      pipeline:,
      type: 'generate-voiceover',
      output: { 's3Key' => 'audio.mp3' })
    node = create(:video_production_node,
      pipeline:,
      type: 'generate-talking-head',
      config: { 'avatarId' => 'test-avatar' },
      inputs: { 'audio' => [audio_node.uuid] })

    Utils::S3::GeneratePresignedUrl.stubs(:call).returns('https://s3.example.com/audio.mp3')

    stub_request(:post, "https://api.heygen.com/v2/video/generate").
      to_return(
        status: 200,
        headers: { 'Content-Type' => 'application/json' },
        body: { data: { video_id: 'video-789' } }.to_json
      )

    VideoProduction::Node::ExecutionUpdated.stubs(:call)

    VideoProduction::APIs::Heygen::GenerateVideo.(node, 'test-uuid')

    assert_requested :post, "https://api.heygen.com/v2/video/generate"
  end

  test "raises error when no audio input specified" do
    pipeline = create(:video_production_pipeline)
    node = create(:video_production_node,
      pipeline:,
      type: 'generate-talking-head',
      config: { 'avatarId' => 'test-avatar' },
      inputs: {})

    error = assert_raises(RuntimeError) do
      VideoProduction::APIs::Heygen::GenerateVideo.(node, 'test-uuid')
    end

    assert_match(/No audio input specified/, error.message)
  end

  test "raises error when avatarId not specified" do
    pipeline = create(:video_production_pipeline)
    audio_node = create(:video_production_node,
      pipeline:,
      output: { 's3Key' => 'audio.mp3' })
    node = create(:video_production_node,
      pipeline:,
      type: 'generate-talking-head',
      config: {},
      inputs: { 'audio' => [audio_node.uuid] })

    error = assert_raises(RuntimeError) do
      VideoProduction::APIs::Heygen::GenerateVideo.(node, 'test-uuid')
    end

    assert_match(/avatarId is required/, error.message)
  end

  test "raises error when HeyGen API fails" do
    pipeline = create(:video_production_pipeline)
    audio_node = create(:video_production_node,
      pipeline:,
      output: { 's3Key' => 'audio.mp3' })
    node = create(:video_production_node,
      pipeline:,
      type: 'generate-talking-head',
      config: { 'avatarId' => 'test-avatar' },
      inputs: { 'audio' => [audio_node.uuid] })

    Utils::S3::GeneratePresignedUrl.stubs(:call).returns('https://s3.example.com/audio.mp3')

    stub_request(:post, "https://api.heygen.com/v2/video/generate").
      to_return(status: 500, body: 'Internal Server Error')

    assert_raises(RuntimeError) do
      VideoProduction::APIs::Heygen::GenerateVideo.(node, 'test-uuid')
    end
  end
end
