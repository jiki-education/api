FactoryBot.define do
  factory :user_challenge do
    user
    challenge

    trait :started do
      started_at { Time.current }
    end

    trait :completed do
      started_at { 2.hours.ago }
      completed_at { Time.current }
    end
  end
end
