FactoryBot.define do
  factory :lesson do
    level
    sequence(:slug) { |n| "lesson-#{n}" }

    trait :exercise do
      type { "exercise" }
    end

    trait :video do
      type { "video" }
      data { { sources: [{ id: "abc123" }] } }
    end

    trait :choose_language do
      type { "choose_language" }
      data { { sources: [{ id: "choose-lang-intro" }] } }
    end
  end
end
