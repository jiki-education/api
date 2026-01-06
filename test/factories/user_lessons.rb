FactoryBot.define do
  factory :user_lesson do
    user
    lesson

    trait :completed do
      completed_at { Time.current }
    end
  end
end
