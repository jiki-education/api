class VideoProduction::Node::Schemas::GenerateAnimation
  INPUTS = {
    'prompt' => {
      type: :single,
      required: false,
      description: 'Reference to asset node with animation prompt'
    },
    'referenceImage' => {
      type: :single,
      required: false,
      description: 'Optional reference image for animation generation'
    }
  }.freeze

  CONFIG = {
    'provider' => {
      type: :string,
      required: true,
      allowed_values: %w[veo3 runway stability],
      description: 'Animation generation provider'
    }
  }.freeze
end
