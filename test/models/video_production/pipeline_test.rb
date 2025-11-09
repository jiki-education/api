require "test_helper"

module VideoProduction
  class PipelineTest < ActiveSupport::TestCase
    test "valid factory" do
      assert build(:video_production_pipeline).valid?
    end

    test "validates presence of title" do
      pipeline = build(:video_production_pipeline, title: nil)
      refute pipeline.valid?
      assert_includes pipeline.errors[:title], "can't be blank"
    end

    test "validates presence of version" do
      pipeline = build(:video_production_pipeline, version: nil)
      refute pipeline.valid?
      assert_includes pipeline.errors[:version], "can't be blank"
    end

    test "generates uuid on creation" do
      pipeline = create(:video_production_pipeline)
      assert pipeline.uuid.present?
      assert_match(/^[a-f0-9-]{36}$/, pipeline.uuid) # UUID format
    end

    test "validates uniqueness of uuid on update" do
      pipeline1 = create(:video_production_pipeline)
      pipeline2 = create(:video_production_pipeline)
      pipeline2.uuid = pipeline1.uuid

      refute pipeline2.valid?(:update)
      assert_includes pipeline2.errors[:uuid], "has already been taken"
    end

    test "to_param returns uuid" do
      pipeline = create(:video_production_pipeline)
      assert_equal pipeline.uuid, pipeline.to_param
    end

    test "has many nodes" do
      pipeline = create(:video_production_pipeline)
      node1 = create(:video_production_node, pipeline: pipeline)
      node2 = create(:video_production_node, pipeline: pipeline)

      assert_equal 2, pipeline.nodes.count
      assert_includes pipeline.nodes, node1
      assert_includes pipeline.nodes, node2
    end

    test "deleting pipeline cascades to delete nodes" do
      pipeline = create(:video_production_pipeline)
      node1 = create(:video_production_node, pipeline: pipeline)
      node2 = create(:video_production_node, pipeline: pipeline)

      node1_id = node1.id
      node2_id = node2.id

      pipeline.destroy!

      refute VideoProduction::Node.exists?(node1_id)
      refute VideoProduction::Node.exists?(node2_id)
    end

    test "config accessor works" do
      pipeline = create(:video_production_pipeline)
      assert pipeline.config.present?
      assert_equal 'jiki-videos-test', pipeline.config['storage']['bucket']
    end

    test "metadata accessor works" do
      pipeline = create(:video_production_pipeline)
      assert pipeline.metadata.present?
      assert_equal 0, pipeline.metadata['totalCost']
    end

    test "progress_summary returns default when no progress" do
      pipeline = create(:video_production_pipeline, metadata: {})

      expected = {
        'completed' => 0,
        'in_progress' => 0,
        'pending' => 0,
        'failed' => 0,
        'total' => 0
      }

      assert_equal expected, pipeline.progress_summary
    end

    test "progress_summary returns metadata progress when present" do
      progress = {
        'completed' => 5,
        'in_progress' => 2,
        'pending' => 3,
        'failed' => 1,
        'total' => 11
      }

      pipeline = create(:video_production_pipeline, metadata: { 'progress' => progress })

      assert_equal progress, pipeline.progress_summary
    end
  end
end
