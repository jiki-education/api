require "test_helper"

class VideoProduction::Node::ValidateConfigTest < ActiveSupport::TestCase
  test "returns empty hash when config schema is nil" do
    pipeline = create(:video_production_pipeline)
    node = build(:video_production_node, pipeline:, type: 'asset', config: {})

    result = VideoProduction::Node::ValidateConfig.(node, nil)

    assert_empty result
  end

  test "returns empty hash when config schema is empty" do
    pipeline = create(:video_production_pipeline)
    node = build(:video_production_node, pipeline:, type: 'asset', config: {})

    result = VideoProduction::Node::ValidateConfig.(node, {})

    assert_empty result
  end

  test "returns empty hash when all required config keys are present" do
    pipeline = create(:video_production_pipeline)
    node = build(:video_production_node,
      pipeline:,
      type: 'generate-talking-head',
      config: {
        'provider' => 'heygen',
        'avatarId' => 'avatar-1'
      })

    # Schema now has required fields
    schema = VideoProduction::Node::Schemas::GenerateTalkingHead::CONFIG
    result = VideoProduction::Node::ValidateConfig.(node, schema)

    assert_empty result
  end

  test "returns error when required config key is missing" do
    pipeline = create(:video_production_pipeline)
    node = build(:video_production_node,
      pipeline:,
      type: 'test-node',
      config: {}) # missing required key

    # Custom schema for testing
    schema = {
      'provider' => {
        type: :string,
        required: true
      }
    }
    result = VideoProduction::Node::ValidateConfig.(node, schema)

    assert result.key?(:provider)
    assert_equal "is required for test-node nodes", result[:provider]
  end

  test "returns error for invalid config value type - string" do
    pipeline = create(:video_production_pipeline)
    node = build(:video_production_node,
      pipeline:,
      type: 'test-node',
      config: {
        'provider' => 123 # should be string
      })

    schema = {
      'provider' => {
        type: :string,
        required: true
      }
    }
    result = VideoProduction::Node::ValidateConfig.(node, schema)

    assert result.key?(:provider)
    assert_equal "must be a string", result[:provider]
  end

  test "returns error for invalid array type" do
    pipeline = create(:video_production_pipeline)
    node = build(:video_production_node,
      pipeline:,
      type: 'test-node',
      config: {
        'layers' => 'not-an-array' # should be array
      })

    schema = {
      'layers' => {
        type: :array,
        required: true
      }
    }
    result = VideoProduction::Node::ValidateConfig.(node, schema)

    assert result.key?(:layers)
    assert_equal "must be a array", result[:layers]
  end

  test "returns error for invalid hash type" do
    pipeline = create(:video_production_pipeline)
    node = build(:video_production_node,
      pipeline:,
      type: 'test-node',
      config: {
        'inputProps' => 'not-a-hash' # should be hash
      })

    schema = {
      'inputProps' => {
        type: :hash,
        required: true
      }
    }
    result = VideoProduction::Node::ValidateConfig.(node, schema)

    assert result.key?(:inputProps)
    assert_equal "must be a hash", result[:inputProps]
  end

  test "validates correctly and returns early on first error" do
    pipeline = create(:video_production_pipeline)
    node = build(:video_production_node,
      pipeline:,
      type: 'test-node',
      config: {
        'provider' => 123 # invalid type
      })

    schema = {
      'provider' => {
        type: :string,
        required: true
      },
      'apiKey' => {
        type: :string,
        required: true
      }
    }
    result = VideoProduction::Node::ValidateConfig.(node, schema)

    # Should return first error (provider type)
    assert result.key?(:provider)
    assert_equal "must be a string", result[:provider]
  end

  test "allows optional config keys to be missing" do
    pipeline = create(:video_production_pipeline)
    node = build(:video_production_node,
      pipeline:,
      type: 'test-node',
      config: {
        'provider' => 'ffmpeg'
        # volume is optional, not included
      })

    schema = {
      'provider' => {
        type: :string,
        required: true
      },
      'volume' => {
        type: :integer,
        required: false
      }
    }
    result = VideoProduction::Node::ValidateConfig.(node, schema)

    assert_empty result
  end

  test "validates boolean type correctly" do
    pipeline = create(:video_production_pipeline)
    node = build(:video_production_node,
      pipeline:,
      type: 'test-node',
      config: {
        'transparentBackground' => 'yes' # should be boolean
      })

    schema = {
      'transparentBackground' => {
        type: :boolean,
        required: true
      }
    }
    result = VideoProduction::Node::ValidateConfig.(node, schema)

    assert result.key?(:transparentBackground)
    assert_equal "must be a boolean", result[:transparentBackground]
  end

  test "validates integer type correctly" do
    pipeline = create(:video_production_pipeline)
    node = build(:video_production_node,
      pipeline:,
      type: 'test-node',
      config: {
        'width' => '1920' # should be integer
      })

    schema = {
      'width' => {
        type: :integer,
        required: true
      }
    }
    result = VideoProduction::Node::ValidateConfig.(node, schema)

    assert result.key?(:width)
    assert_equal "must be a integer", result[:width]
  end

  test "validates allowed_values constraint" do
    pipeline = create(:video_production_pipeline)
    node = build(:video_production_node,
      pipeline:,
      type: 'test-node',
      config: {
        'provider' => 'invalid-provider'
      })

    schema = {
      'provider' => {
        type: :string,
        required: true,
        allowed_values: %w[heygen remotion ffmpeg]
      }
    }
    result = VideoProduction::Node::ValidateConfig.(node, schema)

    assert result.key?(:provider)
    assert_equal "must be one of: heygen, remotion, ffmpeg", result[:provider]
  end
end
