module VideoProduction
  class Pipeline < ApplicationRecord
    self.table_name = 'video_production_pipelines'

    has_many :nodes, class_name: 'VideoProduction::Node', dependent: :destroy, inverse_of: :pipeline

    validates :uuid, presence: true, uniqueness: true, on: :update
    validates :title, presence: true
    validates :version, presence: true

    # JSONB accessors
    store_accessor :config, :storage, :working_directory
    store_accessor :metadata, :total_cost, :estimated_total_cost, :progress

    before_validation(on: :create) do
      self.uuid ||= SecureRandom.uuid
    end

    def to_param = uuid

    def progress_summary
      metadata['progress'] || {
        'completed' => 0,
        'in_progress' => 0,
        'pending' => 0,
        'failed' => 0,
        'total' => 0
      }
    end
  end
end
