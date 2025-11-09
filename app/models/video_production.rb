module VideoProduction
  # Valid node types
  NODE_TYPES = %w[
    asset
    generate-talking-head
    generate-animation
    generate-voiceover
    render-code
    mix-audio
    merge-videos
    compose-video
  ].freeze
end
