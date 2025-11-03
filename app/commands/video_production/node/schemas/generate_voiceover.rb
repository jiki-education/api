class VideoProduction::Node::Schemas::GenerateVoiceover
  INPUTS = {
    'script' => {
      type: :single,
      required: false,
      description: 'Reference to asset node with voiceover script'
    }
  }.freeze

  CONFIG = {
    'provider' => {
      type: :string,
      required: true,
      allowed_values: %w[elevenlabs],
      description: 'Voiceover generation provider'
    }
  }.freeze
end
