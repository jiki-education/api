class SerializeAdminVideoProductionPipelines
  include Mandate

  initialize_with :pipelines

  def call
    pipelines.map { |pipeline| SerializeAdminVideoProductionPipeline.(pipeline) }
  end
end
