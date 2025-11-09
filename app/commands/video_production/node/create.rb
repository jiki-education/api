class VideoProduction::Node::Create
  include Mandate

  initialize_with :pipeline, :params

  def call
    node = pipeline.nodes.new(params)
    node.assign_attributes(VideoProduction::Node::Validate.(node))
    node.save!
    node
  end
end
