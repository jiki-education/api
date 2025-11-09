class VideoProduction::Node::Schemas::ComposeVideo
  INPUTS = {
    'background' => {
      type: :single,
      required: true,
      description: 'Background video node reference'
    },
    'overlay' => {
      type: :single,
      required: true,
      description: 'Overlay video node reference (e.g., talking head)'
    }
  }.freeze

  CONFIG = {
    'rounded' => {
      type: :boolean,
      required: true,
      description: 'Apply rounded corners to overlay video'
    },
    'cropTop' => {
      type: :integer,
      required: false,
      description: 'Crop from top edge in pixels'
    },
    'cropLeft' => {
      type: :integer,
      required: false,
      description: 'Crop from left edge in pixels'
    },
    'cropWidth' => {
      type: :integer,
      required: false,
      description: 'Width of cropped region in pixels'
    },
    'cropHeight' => {
      type: :integer,
      required: false,
      description: 'Height of cropped region in pixels'
    },
    'provider' => {
      type: :string,
      required: true,
      allowed_values: %w[ffmpeg],
      description: 'Video composition provider'
    }
  }.freeze
end
