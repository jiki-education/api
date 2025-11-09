class VideoProduction::Node::Schemas::MixAudio
  INPUTS = {
    'video' => {
      type: :single,
      required: true,
      description: 'Reference to video node'
    },
    'audio' => {
      type: :single,
      required: true,
      description: 'Reference to audio node'
    }
  }.freeze

  CONFIG = {
    'provider' => {
      type: :string,
      required: true,
      allowed_values: %w[ffmpeg],
      description: 'Audio mixing provider'
    }
  }.freeze
end
