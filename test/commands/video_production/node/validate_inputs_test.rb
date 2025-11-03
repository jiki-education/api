require "test_helper"

class VideoProduction::Node::ValidateInputsTest < ActiveSupport::TestCase
  # Tests for :multiple type

  test "validates multiple type with valid array" do
    pipeline = create(:video_production_pipeline)
    input1 = create(:video_production_node, pipeline:)
    input2 = create(:video_production_node, pipeline:)
    node = build(:video_production_node,
      pipeline:,
      type: 'merge-videos',
      inputs: { 'segments' => [input1.uuid, input2.uuid] })

    schema = { 'segments' => { type: :multiple, required: true, min_count: 2 } }
    result = VideoProduction::Node::ValidateInputs.(node, schema)

    assert_empty result
  end

  test "validates multiple type fails when not an array" do
    pipeline = create(:video_production_pipeline)
    node = build(:video_production_node,
      pipeline:,
      inputs: { 'segments' => 'not-an-array' })

    schema = { 'segments' => { type: :multiple, required: true } }
    result = VideoProduction::Node::ValidateInputs.(node, schema)

    assert_equal "must be an array", result[:segments]
  end

  test "validates multiple type enforces min_count" do
    pipeline = create(:video_production_pipeline)
    input1 = create(:video_production_node, pipeline:)
    node = build(:video_production_node,
      pipeline:,
      inputs: { 'segments' => [input1.uuid] })

    schema = { 'segments' => { type: :multiple, required: true, min_count: 2 } }
    result = VideoProduction::Node::ValidateInputs.(node, schema)

    assert_equal "requires at least 2 items, got 1", result[:segments]
  end

  test "validates multiple type enforces max_count" do
    pipeline = create(:video_production_pipeline)
    input1 = create(:video_production_node, pipeline:)
    input2 = create(:video_production_node, pipeline:)
    input3 = create(:video_production_node, pipeline:)
    node = build(:video_production_node,
      pipeline:,
      inputs: { 'segments' => [input1.uuid, input2.uuid, input3.uuid] })

    schema = { 'segments' => { type: :multiple, required: true, max_count: 2 } }
    result = VideoProduction::Node::ValidateInputs.(node, schema)

    assert_equal "allows at most 2 items, got 3", result[:segments]
  end

  test "validates multiple type checks node references exist" do
    pipeline = create(:video_production_pipeline)
    node = build(:video_production_node,
      pipeline:,
      inputs: { 'segments' => %w[fake-uuid-1 fake-uuid-2] })

    schema = { 'segments' => { type: :multiple, required: true, min_count: 2 } }
    result = VideoProduction::Node::ValidateInputs.(node, schema)

    assert_match(/references non-existent nodes/, result[:segments])
  end

  # Tests for :single type

  test "validates single type with valid string UUID" do
    pipeline = create(:video_production_pipeline)
    input1 = create(:video_production_node, pipeline:)
    node = build(:video_production_node,
      pipeline:,
      inputs: { 'script' => input1.uuid })

    schema = { 'script' => { type: :single, required: true } }
    result = VideoProduction::Node::ValidateInputs.(node, schema)

    assert_empty result
  end

  test "validates single type fails when value is an array" do
    pipeline = create(:video_production_pipeline)
    input1 = create(:video_production_node, pipeline:)
    node = build(:video_production_node,
      pipeline:,
      inputs: { 'script' => [input1.uuid] })

    schema = { 'script' => { type: :single, required: true } }
    result = VideoProduction::Node::ValidateInputs.(node, schema)

    assert_equal "must be a single node UUID (string), not an array", result[:script]
  end

  test "validates single type checks node reference exists" do
    pipeline = create(:video_production_pipeline)
    node = build(:video_production_node,
      pipeline:,
      inputs: { 'script' => 'fake-uuid' })

    schema = { 'script' => { type: :single, required: true } }
    result = VideoProduction::Node::ValidateInputs.(node, schema)

    assert_match(/references non-existent nodes/, result[:script])
  end

  # Tests for required validation

  test "validates required field is present" do
    pipeline = create(:video_production_pipeline)
    node = build(:video_production_node, pipeline:, inputs: {})

    schema = { 'segments' => { type: :multiple, required: true } }
    result = VideoProduction::Node::ValidateInputs.(node, schema)

    assert_match(/is required/, result[:segments])
  end

  test "allows optional field to be missing" do
    pipeline = create(:video_production_pipeline)
    node = build(:video_production_node, pipeline:, inputs: {})

    schema = { 'script' => { type: :single, required: false } }
    result = VideoProduction::Node::ValidateInputs.(node, schema)

    assert_empty result
  end

  # Tests for unexpected slots

  test "validates unexpected input slots" do
    pipeline = create(:video_production_pipeline)
    input1 = create(:video_production_node, pipeline:)
    input2 = create(:video_production_node, pipeline:)
    node = build(:video_production_node,
      pipeline:,
      inputs: {
        'segments' => [input1.uuid, input2.uuid],
        'unexpected' => ['foo']
      })

    schema = { 'segments' => { type: :multiple, required: true, min_count: 2 } }
    result = VideoProduction::Node::ValidateInputs.(node, schema)

    assert_match(/Unexpected input slot/, result[:unexpected_inputs])
  end

  # Tests for all node types using actual schemas

  test "asset node with no inputs is valid" do
    pipeline = create(:video_production_pipeline)
    node = build(:video_production_node, pipeline:, type: 'asset', inputs: {})

    schema = VideoProduction::Node::Schemas::Asset::INPUTS
    result = VideoProduction::Node::ValidateInputs.(node, schema)

    assert_empty result
  end

  test "asset node with inputs is invalid" do
    pipeline = create(:video_production_pipeline)
    node = build(:video_production_node, pipeline:, type: 'asset', inputs: { 'foo' => 'bar' })

    schema = VideoProduction::Node::Schemas::Asset::INPUTS
    result = VideoProduction::Node::ValidateInputs.(node, schema)

    assert_equal "asset nodes should not have inputs", result[:unexpected_inputs]
  end

  test "generate-talking-head with valid audio input" do
    pipeline = create(:video_production_pipeline)
    audio_node = create(:video_production_node, pipeline:, type: 'generate-voiceover')
    node = build(:video_production_node,
      pipeline:,
      type: 'generate-talking-head',
      inputs: { 'audio' => audio_node.uuid })

    schema = VideoProduction::Node::Schemas::GenerateTalkingHead::INPUTS
    result = VideoProduction::Node::ValidateInputs.(node, schema)

    assert_empty result
  end

  test "generate-talking-head without audio fails (required)" do
    pipeline = create(:video_production_pipeline)
    node = build(:video_production_node, pipeline:, type: 'generate-talking-head', inputs: {})

    schema = VideoProduction::Node::Schemas::GenerateTalkingHead::INPUTS
    result = VideoProduction::Node::ValidateInputs.(node, schema)

    assert_equal "is required for generate-talking-head nodes", result[:audio]
  end

  test "generate-talking-head with audio and background inputs" do
    pipeline = create(:video_production_pipeline)
    audio_node = create(:video_production_node, pipeline:, type: 'generate-voiceover')
    background_node = create(:video_production_node, pipeline:, type: 'asset')
    node = build(:video_production_node,
      pipeline:,
      type: 'generate-talking-head',
      inputs: { 'audio' => audio_node.uuid, 'background' => background_node.uuid })

    schema = VideoProduction::Node::Schemas::GenerateTalkingHead::INPUTS
    result = VideoProduction::Node::ValidateInputs.(node, schema)

    assert_empty result
  end

  test "mix-audio with both video and audio inputs" do
    pipeline = create(:video_production_pipeline)
    video_node = create(:video_production_node, pipeline:)
    audio_node = create(:video_production_node, pipeline:)
    node = build(:video_production_node,
      pipeline:,
      type: 'mix-audio',
      inputs: {
        'video' => video_node.uuid,
        'audio' => audio_node.uuid
      })

    schema = VideoProduction::Node::Schemas::MixAudio::INPUTS
    result = VideoProduction::Node::ValidateInputs.(node, schema)

    assert_empty result
  end

  test "mix-audio without video input is invalid" do
    pipeline = create(:video_production_pipeline)
    audio_node = create(:video_production_node, pipeline:)
    node = build(:video_production_node,
      pipeline:,
      type: 'mix-audio',
      inputs: { 'audio' => audio_node.uuid })

    schema = VideoProduction::Node::Schemas::MixAudio::INPUTS
    result = VideoProduction::Node::ValidateInputs.(node, schema)

    assert_match(/is required/, result[:video])
  end

  test "compose-video with background and overlay" do
    pipeline = create(:video_production_pipeline)
    bg_node = create(:video_production_node, pipeline:)
    overlay_node = create(:video_production_node, pipeline:)
    node = build(:video_production_node,
      pipeline:,
      type: 'compose-video',
      inputs: {
        'background' => bg_node.uuid,
        'overlay' => overlay_node.uuid
      })

    schema = VideoProduction::Node::Schemas::ComposeVideo::INPUTS
    result = VideoProduction::Node::ValidateInputs.(node, schema)

    assert_empty result
  end
end
