FactoryBot.define do
  factory :user_course do
    user
    course
    started_at { Time.current }

    trait :with_javascript do
      language { "javascript" }
    end

    trait :with_python do
      language { "python" }
    end

    trait :completed do
      completed_at { Time.current }
    end
  end
end
