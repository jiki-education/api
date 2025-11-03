FactoryBot.define do
  factory :exercise_submission do
    association :context, factory: :user_lesson
    uuid { SecureRandom.uuid }

    trait :for_lesson do
      association :context, factory: :user_lesson
    end

    trait :for_project do
      association :context, factory: :user_project
    end
  end
end
