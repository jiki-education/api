FactoryBot.define do
  factory :premium_entitlement do
    association :user
    source { PremiumEntitlement::EXERCISM_INSIDER }

    trait :insider do
      source { PremiumEntitlement::EXERCISM_INSIDER }
    end

    trait :bootcamp do
      source { PremiumEntitlement::EXERCISM_BOOTCAMP }
    end

    trait :revoked do
      revoked_at { Time.current }
    end

    trait :expired do
      expires_at { 1.day.ago }
    end
  end
end
