FactoryBot.define do
  factory :user_acquired_badge, class: "User::AcquiredBadge" do
    association :user
    association :badge
    revealed { false }

    trait :revealed do
      revealed { true }
    end
  end
end
