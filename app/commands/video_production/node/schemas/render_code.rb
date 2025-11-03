class VideoProduction::Node::Schemas::RenderCode
  INPUTS = {
    'config' => {
      type: :single,
      required: false,
      description: 'Reference to asset node with Remotion config JSON'
    }
  }.freeze

  CONFIG = {
    'provider' => {
      type: :string,
      required: true,
      allowed_values: %w[remotion],
      description: 'Code rendering provider'
    }
  }.freeze
end
