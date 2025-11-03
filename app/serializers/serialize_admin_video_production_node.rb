class SerializeAdminVideoProductionNode
  include Mandate

  initialize_with :node

  def call
    {
      uuid: node.uuid,
      pipeline_uuid: node.pipeline.uuid,
      title: node.title,
      type: node.type,
      status: node.status,
      inputs: node.inputs,
      config: node.config,
      asset: node.asset,
      metadata: node.metadata,
      output: node.output,
      is_valid: node.is_valid,
      validation_errors: node.validation_errors
    }
  end
end
