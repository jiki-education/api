FactoryBot.define do
  factory :user_project do
    user
    project

    trait :started do
      started_at { Time.current }
    end

    trait :completed do
      started_at { 2.hours.ago }
      completed_at { Time.current }
    end
  end
end
