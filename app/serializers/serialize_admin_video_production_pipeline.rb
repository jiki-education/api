class SerializeAdminVideoProductionPipeline
  include Mandate

  initialize_with :pipeline

  def call
    {
      uuid: pipeline.uuid,
      title: pipeline.title,
      version: pipeline.version,
      config: pipeline.config,
      metadata: pipeline.metadata
    }
  end
end
