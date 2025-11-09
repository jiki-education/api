class VideoProduction::Node::Schemas::GenerateTalkingHead
  INPUTS = {
    'audio' => {
      type: :single,
      required: true,
      description: 'Reference to audio node for avatar speech'
    },
    'background' => {
      type: :single,
      required: false,
      description: 'Reference to image asset node for video background'
    }
  }.freeze

  CONFIG = {
    'provider' => {
      type: :string,
      required: true,
      allowed_values: %w[heygen],
      description: 'Talking head video generation provider'
    },
    'avatarId' => {
      type: :string,
      required: true,
      description: 'HeyGen avatar ID (e.g., "Monica_inSleeveless_20220819")'
    },
    'width' => {
      type: :integer,
      required: false,
      description: 'Video width in pixels (default: 1280)'
    },
    'height' => {
      type: :integer,
      required: false,
      description: 'Video height in pixels (default: 720)'
    }
  }.freeze
end
