FactoryBot.define do
  factory :project do
    sequence(:title) { |n| "Project #{n}" }
    sequence(:description) { |n| "A description for Project #{n}" }
    sequence(:exercise_slug) { |n| "project-#{n}" }

    trait :with_unlocking_lesson do
      association :unlocked_by_lesson, factory: :lesson
    end
  end
end
