FactoryBot.define do
  factory :exercise_submission do
    association :context, factory: :user_lesson
    uuid { SecureRandom.uuid }

    trait :for_lesson do
      association :context, factory: :user_lesson
    end

    trait :for_challenge do
      association :context, factory: :user_challenge
    end
  end
end
