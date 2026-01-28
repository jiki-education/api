FactoryBot.define do
  factory :user_activity_data, class: "User::ActivityData" do
    user
    activity_days { {} }
    current_streak { 0 }
    longest_streak { 0 }
    total_active_days { 0 }

    trait :with_streak do
      transient do
        streak_days { 5 }
      end

      after(:build) do |activity_data, evaluator|
        today = Date.current
        evaluator.streak_days.times do |i|
          activity_data.activity_days[(today - i.days).to_s] = User::ActivityData::ACTIVITY_PRESENT
        end
        activity_data.current_streak = evaluator.streak_days
        activity_data.longest_streak = evaluator.streak_days
        activity_data.total_active_days = evaluator.streak_days
      end
    end
  end
end
