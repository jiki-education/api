class VideoProduction::Node::Schemas::MergeVideos
  INPUTS = {
    'segments' => {
      type: :multiple,
      required: true,
      min_count: 2,
      max_count: nil,
      description: 'Array of video node references to concatenate'
    }
  }.freeze

  CONFIG = {
    'provider' => {
      type: :string,
      required: true,
      allowed_values: %w[ffmpeg],
      description: 'Video merging provider'
    }
  }.freeze
end
