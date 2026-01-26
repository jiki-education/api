FactoryBot.define do
  factory :user_lesson do
    user
    association :lesson, factory: %i[lesson exercise]
    started_at { Time.current }

    after(:build) do |user_lesson|
      level = user_lesson.lesson.level
      create(:user_level, user: user_lesson.user, level:) unless UserLevel.exists?(user: user_lesson.user, level:)
    end

    trait :completed do
      completed_at { Time.current }
    end
  end
end
