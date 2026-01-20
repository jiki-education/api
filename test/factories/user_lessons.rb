FactoryBot.define do
  factory :user_lesson do
    user
    association :lesson, factory: %i[lesson exercise]

    trait :completed do
      completed_at { Time.current }
    end
  end
end
