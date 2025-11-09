module VideoProduction
  class Node < ApplicationRecord
    disable_sti!

    self.table_name = 'video_production_nodes'

    # Node types that can be executed
    NODE_TYPES = %w[
      asset
      generate-talking-head
      generate-animation
      generate-voiceover
      render-code
      mix-audio
      merge-videos
      compose-video
    ].freeze

    belongs_to :pipeline, class_name: 'VideoProduction::Pipeline', inverse_of: :nodes

    validates :uuid, presence: true, uniqueness: true, on: :update
    validates :title, presence: true
    validates :type, presence: true, inclusion: { in: NODE_TYPES }
    validates :status, inclusion: { in: %w[pending in_progress completed failed] }

    # JSONB accessors
    # Note: config, metadata, output, and asset use camelCase keys in JSON
    # Access these directly via hash syntax: node.output['s3Key'], node.config['avatarId'], etc.
    # Exception: 'provider' has a convenience accessor (common field used across all node types)
    store_accessor :config, :provider
    store_accessor :metadata, :process_uuid # process_uuid needs accessor for locking logic

    # Scopes
    scope :pending, -> { where(status: 'pending') }
    scope :in_progress, -> { where(status: 'in_progress') }
    scope :completed, -> { where(status: 'completed') }
    scope :failed, -> { where(status: 'failed') }

    before_validation(on: :create) do
      self.uuid ||= SecureRandom.uuid
    end

    def to_param = uuid

    # Check if all input nodes are completed
    def inputs_satisfied?
      return true if inputs.blank?

      input_node_ids = inputs.values.flatten.compact
      return true if input_node_ids.empty?

      input_nodes = self.class.where(pipeline_id: pipeline_id, uuid: input_node_ids)
      input_nodes.all? { |node| node.status == 'completed' }
    end

    # Check if ready to execute
    # Allows both initial execution (pending) and re-execution after failures (failed)
    def ready_to_execute?
      status.in?(%w[pending failed]) && is_valid? && inputs_satisfied?
    end
  end
end
