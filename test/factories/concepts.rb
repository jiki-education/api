FactoryBot.define do
  factory :concept do
    sequence(:title) { |n| "Concept #{n}" }
    sequence(:description) { |n| "A brief description of Concept #{n}" }
    sequence(:content_markdown) { |n| "# Concept #{n}\n\nThis is the content for Concept #{n}." }

    trait :with_standard_video do
      standard_video_provider { "youtube" }
      standard_video_id { "dQw4w9WgXcQ" }
    end

    trait :with_premium_video do
      premium_video_provider { "mux" }
      premium_video_id { "abc123def456" }
    end

    trait :with_both_videos do
      with_standard_video
      with_premium_video
    end

    trait :with_parent do
      association :parent, factory: :concept
    end

    trait :with_children do
      transient do
        children_count { 2 }
      end

      after(:create) do |concept, evaluator|
        create_list(:concept, evaluator.children_count, parent: concept)
      end
    end
  end
end
