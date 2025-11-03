FactoryBot.define do
  factory :video_production_node, class: 'VideoProduction::Node' do
    association :pipeline, factory: :video_production_pipeline

    title { "Test Node" }
    type { 'asset' }
    inputs { {} }
    config { {} }
    status { 'pending' }

    trait :merge_videos do
      type { 'merge-videos' }
      config { { 'provider' => 'ffmpeg' } }
    end

    trait :talking_head do
      type { 'generate-talking-head' }
      config do
        {
          'provider' => 'heygen',
          'avatarId' => 'avatar-1'
        }
      end
    end

    trait :generate_animation do
      type { 'generate-animation' }
      config do
        {
          'provider' => 'veo3'
        }
      end
    end

    trait :generate_voiceover do
      type { 'generate-voiceover' }
      config do
        {
          'provider' => 'elevenlabs'
        }
      end
    end

    trait :completed do
      status { 'completed' }
      metadata do
        {
          'started_at' => 1.hour.ago.iso8601,
          'completed_at' => Time.current.iso8601,
          'cost' => 0.05
        }
      end
      output do
        {
          'type' => 'video',
          's3Key' => 'output/test.mp4',
          'duration' => 60.0,
          'size' => 5_242_880
        }
      end
    end
  end
end
