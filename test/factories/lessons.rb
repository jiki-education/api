FactoryBot.define do
  factory :lesson do
    level
    sequence(:slug) { |n| "lesson-#{n}" }
    title { "Lesson #{slug}" }
    description { "Description for #{title}" }

    trait :exercise do
      type { "exercise" }
      data { { slug: "basic-movement" } }
    end

    trait :video do
      type { "video" }
      data { { sources: [{ id: "abc123" }] } }
    end
  end
end
