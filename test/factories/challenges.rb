FactoryBot.define do
  factory :challenge do
    sequence(:title) { |n| "Challenge #{n}" }
    sequence(:description) { |n| "A description for Challenge #{n}" }
    sequence(:exercise_slug) { |n| "challenge-#{n}" }

    trait :with_unlocking_lesson do
      association :unlocked_by_lesson, factory: :lesson
    end
  end
end
